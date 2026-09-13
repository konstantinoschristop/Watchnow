//
//  AlertInputs.swift
//  Watchnow
//
//  Gathers what `AlertPlanner` needs out of the stores, so the planner can
//  stay a pure function of values it was handed.
//
//  Nothing here fetches. Every fact already exists: the watchlist knows what
//  is saved and when it was saved, `WatchlistChangeStore`'s snapshots know
//  each series' next air date (refreshed twice a day by
//  `WatchlistChangeMonitor` since v2.0), and `AlertPreferences` knows what
//  the user muted. This is the join, not a new source of truth.
//

import Foundation

@MainActor
enum AlertInputs {

    /// Every dated upcoming episode of a saved, unmuted series.
    ///
    /// A series with no snapshot yet contributes nothing — the monitor
    /// establishes one on its next pass and the following plan picks it up.
    /// Same for a series whose next air date is still TBA: nothing is
    /// scheduled and nothing is guessed.
    static func episodeEvents(now: Date = Date()) -> [EpisodeEvent] {
        WatchlistManager.watchlist.compactMap { item -> EpisodeEvent? in
            guard let id = item.id, item.inferredScreenType == .tv else { return nil }

            let kinds = AutoAlertPolicy.alertKinds(
                for: AlertPreferences.policyInputs(forID: id, isSaved: true))
            guard kinds.contains(.episode) else { return nil }

            guard let snapshot = WatchlistChangeStore.snapshot(mediaType: "tv", mediaID: id),
                  let airDate = parseDay(snapshot.nextEpisodeAirDate)
            else { return nil }

            return EpisodeEvent(mediaID: id,
                                seriesTitle: snapshot.title,
                                episodeID: snapshot.nextEpisodeID,
                                seasonNumber: snapshot.nextEpisodeSeason,
                                episodeNumber: snapshot.nextEpisodeNumber,
                                airDate: airDate,
                                savedAt: WatchlistManager.addedDate(forID: id))
        }
    }

    /// The user's own bell reminders, read back out of what iOS is holding.
    ///
    /// iOS is the source of truth rather than `ReminderManager`'s identifier
    /// mirror, because the mirror can lag: a fired reminder leaves the
    /// pending list immediately but stays in the mirror until something
    /// calls `reconcileWithSystem`. Planning against a stale list would
    /// reserve slots for notifications that have already been delivered.
    nonisolated static func manualReminders(from pending: [PendingRequest]) -> [ManualReminder] {
        pending.compactMap { request in
            guard request.identifier.hasPrefix(AlertPlanner.manualPrefix),
                  let fireDate = request.fireDate
            else { return nil }
            return ManualReminder(identifier: request.identifier,
                                  fireDate: fireDate,
                                  mediaID: ReminderManager.mediaID(from: request.identifier),
                                  episodeID: ReminderManager.episodeID(from: request.identifier))
        }
    }

    /// TMDB air dates are date-only; parsed as UTC midnight, exactly as
    /// every other date in the app is.
    private static func parseDay(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .iso8601)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.date(from: raw)
    }
}
