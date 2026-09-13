//
//  AlertPlanner.swift
//  Watchnow
//
//  Decides exactly which automatic notifications should exist, and when.
//
//  Everything about restraint lives here and nowhere else: the daily caps,
//  the quiet hours, iOS's 64-pending-request ceiling, and the rule that a
//  reminder the user set by hand always outranks one we inferred. Scattering
//  those across call sites is how an app ends up sending four notifications
//  about the same show in one evening, so they are enforced in one pure
//  function over value types — no store, no network, no `Date()` — which is
//  what makes every rule below provable in a unit test.
//
//  The planner computes the *desired* state from scratch each run. It never
//  reads back its own previous output; reconciling desired against actual is
//  `AlertScheduler`'s job, which is what makes running it twice a no-op.
//

import Foundation

// MARK: - Inputs

/// A known, dated episode of a series the user saved.
struct EpisodeEvent: Equatable, Sendable {

    let mediaID: Int
    let seriesTitle: String
    /// TMDB's episode id, when known. Used to recognise a manual reminder
    /// for the very same episode.
    let episodeID: Int?
    let seasonNumber: Int?
    let episodeNumber: Int?
    /// The day it airs. TMDB reports date-only, parsed as UTC midnight —
    /// the planner pins the time itself.
    let airDate: Date
    /// When the series was saved. The last tiebreak when trimming: if two
    /// alerts are otherwise equal, the one the user added most recently is
    /// the one they are still thinking about.
    let savedAt: Date?

    init(mediaID: Int,
         seriesTitle: String,
         episodeID: Int? = nil,
         seasonNumber: Int? = nil,
         episodeNumber: Int? = nil,
         airDate: Date,
         savedAt: Date? = nil) {
        self.mediaID = mediaID
        self.seriesTitle = seriesTitle
        self.episodeID = episodeID
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.airDate = airDate
        self.savedAt = savedAt
    }
}

/// A reminder the user set by hand with the bell, already scheduled with
/// iOS. Immovable: the planner counts these against its caps but never
/// plans one, never replaces one, and never evicts one.
struct ManualReminder: Equatable, Sendable {

    let identifier: String
    let fireDate: Date
    /// The movie or series it belongs to, when the identifier encodes one.
    /// `reminder.episode.<episodeID>` carries an episode id instead, so this
    /// is nil for those — `episodeID` below covers them.
    let mediaID: Int?
    /// The episode it belongs to, for episode-level reminders.
    let episodeID: Int?

    init(identifier: String, fireDate: Date, mediaID: Int? = nil, episodeID: Int? = nil) {
        self.identifier = identifier
        self.fireDate = fireDate
        self.mediaID = mediaID
        self.episodeID = episodeID
    }
}

// MARK: - Output

/// One notification the app intends to have scheduled.
struct PlannedAlert: Equatable, Sendable {

    let identifier: String
    let title: String
    let body: String
    let fireDate: Date
    let deepLink: DeepLink
    let kind: AlertKind
}

// MARK: - Planner

enum AlertPlanner {

    // MARK: Caps

    /// iOS keeps at most 64 pending requests per app and silently drops the
    /// rest, so this is a hard ceiling rather than a preference. Manual
    /// reminders are counted inside it.
    static let maxPending = 64

    /// Per calendar day, across every title and both kinds — manual
    /// reminders included.
    static let maxPerDay = 3

    /// Per title, per calendar day. A show that drops a whole season at once
    /// gets one alert, not ten.
    static let maxPerTitlePerDay = 1

    /// Episode alerts land at 18:00 local: after work, before the evening is
    /// already decided.
    static let episodeHour = 18

    /// Nothing is delivered from 22:00 up to this hour. Anything that would
    /// land inside the window is moved to `quietEndHour` instead of being
    /// dropped — the news keeps, the 3am buzz does not.
    static let quietStartHour = 22
    static let quietEndHour = 9

    /// Identifier namespaces. Everything the planner owns begins with
    /// `auto.`; everything the user set by hand begins with `reminder.`
    /// (see `ReminderManager`). The split is what lets `AlertScheduler`
    /// clean up after itself without ever touching the user's own reminders.
    static let autoPrefix = "auto."
    static let manualPrefix = "reminder."

    // MARK: - Plan

    /// The full set of automatic notifications that should be scheduled,
    /// ordered by fire date.
    ///
    /// - Parameters:
    ///   - episodes: dated episodes of saved, unmuted series.
    ///   - manualReminders: what the user already set with the bell.
    ///   - now: anything in the past is not planned.
    ///   - calendar: supplies the local day and time zone. Injected so the
    ///     quiet-hour and per-day rules can be tested in a fixed zone.
    static func plan(episodes: [EpisodeEvent],
                     manualReminders: [ManualReminder] = [],
                     now: Date = Date(),
                     calendar: Calendar = .current) -> [PlannedAlert] {

        var candidates: [(alert: PlannedAlert, savedAt: Date?)] = []

        for event in episodes {
            guard let fireDate = fireDate(forAirDate: event.airDate, calendar: calendar),
                  fireDate > now,
                  !isCoveredByManualReminder(event, fireDate: fireDate,
                                             manualReminders: manualReminders,
                                             calendar: calendar)
            else { continue }

            candidates.append((
                PlannedAlert(identifier: episodeIdentifier(mediaID: event.mediaID,
                                                           fireDate: fireDate,
                                                           calendar: calendar),
                             title: "New episode",
                             body: episodeBody(for: event),
                             fireDate: fireDate,
                             deepLink: DeepLink(id: event.mediaID, mediaType: .tv),
                             kind: .episode),
                event.savedAt
            ))
        }

        return trim(candidates, manualReminders: manualReminders, calendar: calendar)
    }

    // MARK: - Timing

    /// 18:00 local on the air date, moved out of quiet hours if it lands
    /// there. Returns nil only when the date can't be expressed in the given
    /// calendar, which in practice means never.
    static func fireDate(forAirDate airDate: Date, calendar: Calendar) -> Date? {
        // TMDB air dates are date-only and parsed as UTC midnight. Read the
        // day in UTC and rebuild it in the local calendar, so a user in
        // Auckland is told about Tuesday's episode on their Tuesday.
        var utc = calendar
        utc.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        let day = utc.dateComponents([.year, .month, .day], from: airDate)

        var local = DateComponents()
        local.year = day.year
        local.month = day.month
        local.day = day.day
        local.hour = episodeHour
        local.minute = 0

        guard let candidate = calendar.date(from: local) else { return nil }
        return movedOutOfQuietHours(candidate, calendar: calendar)
    }

    /// Pushes a fire date out of the 22:00–09:00 window to the next 09:00.
    /// Anything already inside the waking day is returned untouched.
    static func movedOutOfQuietHours(_ date: Date, calendar: Calendar) -> Date {
        let hour = calendar.component(.hour, from: date)
        guard hour >= quietStartHour || hour < quietEndHour else { return date }

        // Late evening rolls to the following morning; the small hours stay
        // on the same calendar day they are already in.
        let base = hour >= quietStartHour
            ? calendar.date(byAdding: .day, value: 1, to: date) ?? date
            : date

        var comps = calendar.dateComponents([.year, .month, .day], from: base)
        comps.hour = quietEndHour
        comps.minute = 0
        return calendar.date(from: comps) ?? date
    }

    // MARK: - Identity

    /// `auto.episode.<mediaID>.<yyyyMMdd>`.
    ///
    /// The fire *day* is part of the identity on purpose. When TMDB moves an
    /// air date the old identifier stops being planned and the new one
    /// appears, so `AlertScheduler` heals the schedule by doing nothing
    /// clever — it removes what is no longer planned and adds what is. It
    /// also makes the one-per-title-per-day cap true by construction.
    static func episodeIdentifier(mediaID: Int, fireDate: Date, calendar: Calendar) -> String {
        "\(autoPrefix)episode.\(mediaID).\(dayKey(fireDate, calendar: calendar))"
    }

    private static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: - Copy

    private static func episodeBody(for event: EpisodeEvent) -> String {
        if let season = event.seasonNumber, let episode = event.episodeNumber {
            return "\(event.seriesTitle) S\(season)E\(episode) airs today"
        }
        return "A new episode of \(event.seriesTitle) airs today"
    }

    // MARK: - Deduplication

    /// Whether the user has already asked to be told about this exact thing.
    /// Matches an episode-level reminder by episode id, and a title- or
    /// season-level one by media id landing on the same local day.
    private static func isCoveredByManualReminder(_ event: EpisodeEvent,
                                                  fireDate: Date,
                                                  manualReminders: [ManualReminder],
                                                  calendar: Calendar) -> Bool {
        manualReminders.contains { reminder in
            if let episodeID = event.episodeID, reminder.episodeID == episodeID { return true }
            guard reminder.mediaID == event.mediaID else { return false }
            return calendar.isDate(reminder.fireDate, inSameDayAs: fireDate)
        }
    }

    // MARK: - Trimming

    /// Applies every cap, in the order that makes the survivors the right
    /// ones: soonest first, most-recently-saved as the tiebreak, and manual
    /// reminders holding their slots throughout.
    private static func trim(_ candidates: [(alert: PlannedAlert, savedAt: Date?)],
                             manualReminders: [ManualReminder],
                             calendar: Calendar) -> [PlannedAlert] {

        let ordered = candidates.sorted { lhs, rhs in
            if lhs.alert.fireDate != rhs.alert.fireDate {
                return lhs.alert.fireDate < rhs.alert.fireDate
            }
            // More recently saved wins. A title with no saved date recorded
            // (anything from before v1.4) sorts last rather than crashing
            // the comparison.
            let lhsSaved = lhs.savedAt ?? .distantPast
            let rhsSaved = rhs.savedAt ?? .distantPast
            if lhsSaved != rhsSaved { return lhsSaved > rhsSaved }
            return lhs.alert.identifier < rhs.alert.identifier
        }

        // Manual reminders occupy their slots before anything is planned.
        var perDay: [String: Int] = [:]
        for reminder in manualReminders {
            perDay[dayKey(reminder.fireDate, calendar: calendar), default: 0] += 1
        }
        var remainingPending = maxPending - manualReminders.count

        var perTitlePerDay: [String: Int] = [:]
        var kept: [PlannedAlert] = []

        for candidate in ordered {
            guard remainingPending > 0 else { break }

            let day = dayKey(candidate.alert.fireDate, calendar: calendar)
            let titleDay = "\(candidate.alert.deepLink.id).\(day)"

            guard perTitlePerDay[titleDay, default: 0] < maxPerTitlePerDay else { continue }
            guard perDay[day, default: 0] < maxPerDay else { continue }

            kept.append(candidate.alert)
            perTitlePerDay[titleDay, default: 0] += 1
            perDay[day, default: 0] += 1
            remainingPending -= 1
        }

        return kept
    }
}
