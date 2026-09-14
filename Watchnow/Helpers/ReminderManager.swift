//
//  ReminderManager.swift
//  Watchnow
//
//  Local-notification reminders for unreleased content. Users tap a
//  "Remind Me" action on movies / TV shows / individual seasons that
//  haven't aired yet, and we fire a local notification on release day
//  (09:00 local) so the title resurfaces when they can actually watch it.
//
//  Storage:
//   - `UNUserNotificationCenter` owns the scheduled requests themselves
//   - We mirror the set of identifiers in `UserDefaults` so the UI can
//     synchronously reflect "reminder set" state without an async lookup
//     on every render.
//

import Foundation
import UserNotifications
import UIKit

@MainActor
enum ReminderManager {

    @UserDefault("scheduledReminderIDs", defaultValue: [])
    private static var scheduledIDs: [String]

    // MARK: - Identifiers

    /// Identifier for a movie / TV-show level reminder.
    static func titleIdentifier(resultID: Int) -> String {
        "reminder.title.\(resultID)"
    }

    /// Identifier for a specific season of a series.
    static func seasonIdentifier(seriesID: Int, seasonNumber: Int) -> String {
        "reminder.season.\(seriesID).\(seasonNumber)"
    }

    /// Identifier for an individual episode.
    static func episodeIdentifier(episodeID: Int) -> String {
        "reminder.episode.\(episodeID)"
    }

    // MARK: - Reading an identifier back

    /// The movie / series an identifier belongs to, or nil when it doesn't
    /// name one. `reminder.episode.<episodeID>` carries an episode id rather
    /// than a media id, so it returns nil here and is answered by
    /// `episodeID(from:)` instead.
    ///
    /// This lives beside the builders above on purpose: the format has
    /// exactly one owner, and `AlertPlanner`'s dedupe rule needs to read it
    /// without inventing a second copy of the grammar.
    nonisolated static func mediaID(from identifier: String) -> Int? {
        let parts = identifier.split(separator: ".")
        guard parts.count >= 3, parts[0] == "reminder" else { return nil }
        switch parts[1] {
        case "title", "season", "watch": return Int(parts[2])
        default:                         return nil
        }
    }

    /// The episode an identifier belongs to, for episode-level reminders.
    nonisolated static func episodeID(from identifier: String) -> Int? {
        let parts = identifier.split(separator: ".")
        guard parts.count >= 3, parts[0] == "reminder", parts[1] == "episode" else { return nil }
        return Int(parts[2])
    }

    // MARK: - Authorization

    /// Returns whether notification authorization is granted. Prompts the
    /// first time; subsequent calls just return the cached status.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default:
            return false
        }
    }

    // MARK: - Scheduling

    /// Distinct outcomes of a `schedule(...)` call. The UI needs to tell
    /// "user has notifications turned off" (offer a path to Settings)
    /// apart from a generic failure (don't nag the user).
    enum ScheduleResult {
        case scheduled
        case authorizationDenied
        case failed
    }

    /// Schedule a one-shot local notification on `date`, at `atHour` local.
    /// Returns `.authorizationDenied` if the OS-level permission is off,
    /// `.failed` for past dates or rejected requests, `.scheduled` on
    /// success.
    ///
    /// `atHour` defaults to 09:00, which is right for the case this was
    /// written for — a title the user asked to be reminded about on its
    /// release day. Callers whose copy implies a time of day should say so;
    /// see the watch nudge below.
    ///
    /// `debugFiresImmediately` controls whether a debug build is allowed to
    /// collapse the wait to a few seconds. On by default because that is the
    /// only way to test a release-day deep link without waiting for a
    /// release day, and off for anything whose *delay is the feature*.
    @discardableResult
    static func schedule(identifier: String,
                         title: String,
                         body: String,
                         on date: Date,
                         atHour: Int = 9,
                         deepLink: DeepLink? = nil,
                         debugFiresImmediately: Bool = true) async -> ScheduleResult {

        guard await requestAuthorization() else { return .authorizationDenied }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let deepLink {
            content.userInfo = deepLink.userInfo
        }

        // Debug builds may fire ~3s from scheduling regardless of `date`, so
        // deeplink wiring can be tested end-to-end without waiting for a
        // real release or air date. Everything else — and every release
        // build — uses the real date pinned to `atHour` local.
        let trigger: UNNotificationTrigger
        #if DEBUG
        let collapseForDebug = debugFiresImmediately
        #else
        let collapseForDebug = false
        #endif

        if collapseForDebug {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        } else {
            let fireDate = fireDate(for: date, atHour: atHour)
            guard fireDate > Date() else { return .failed }
            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireDate
            )
            trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        }

        let request = UNNotificationRequest(identifier: identifier,
                                            content: content,
                                            trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
            if !scheduledIDs.contains(identifier) {
                scheduledIDs.append(identifier)
            }
            return .scheduled
        } catch {
            return .failed
        }
    }

    // MARK: - Settings deeplink

    /// Opens the system Settings app at this app's notification preferences.
    /// Used by the "Notifications off" alert that surfaces when the user
    /// taps a bell after previously denying notification permission.
    @MainActor
    static func openNotificationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    static func cancel(identifier: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
        scheduledIDs.removeAll { $0 == identifier }
    }

    static func isScheduled(identifier: String) -> Bool {
        scheduledIDs.contains(identifier)
    }

    /// Sync our persisted identifier set with what iOS still has pending.
    /// Once a notification fires, iOS removes the request from its pending
    /// list but our cache doesn't know — so the bell would keep rendering
    /// as "on" until the user manually toggled it off. Call this on view
    /// appear (and on app foreground) so the UI catches up.
    static func reconcileWithSystem() async {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let pendingIDs = Set(pending.map(\.identifier))
        scheduledIDs.removeAll { !pendingIDs.contains($0) }
    }

    // MARK: - Onboarding watch nudge

    /// The one notification this app sends about something that has
    /// *already* happened.
    ///
    /// Both automatic alerts fire on a change — a next episode airing, a
    /// title newly reaching a service you have — so neither can ever fire
    /// for a title that was already streaming the moment it was saved. Since
    /// onboarding's third step now leads with exactly those titles, a first
    /// session could otherwise end with three saves and nothing that will
    /// ever bring the user back to them.
    ///
    /// Deliberately one, once. The `reminder.` prefix is load-bearing:
    /// `AlertPlanner` counts anything carrying it against the same daily
    /// caps as a bell the user set by hand, so this cannot stack on top of
    /// an episode alert the same morning. `watch` rather than `title` keeps
    /// it from being mistaken for a real bell in the details screen's state.
    struct WatchNudge: Codable, Equatable {
        let mediaID: Int
        let mediaType: String
        let title: String
        let due: Date
    }

    @UserDefault("pendingWatchNudge", defaultValue: nil)
    private static var pendingNudge: WatchNudge?

    static func nudgeIdentifier(mediaID: Int) -> String { "reminder.watch.\(mediaID)" }

    /// Long enough not to be a second notification about the thing they did
    /// thirty seconds ago; short enough that the title is still a decision
    /// they remember making.
    private static let nudgeDelay: TimeInterval = 2 * 24 * 60 * 60

    /// Early evening, which is when a person actually decides what to watch.
    /// The body asks "fancy it tonight?", so arriving at 09:00 — the default
    /// for a release-day reminder — would make the copy false. Sits just
    /// after `AlertPlanner.episodeHour` (18:00) and well clear of that
    /// planner's 22:00 quiet-hour boundary.
    private static let nudgeHour = 19

    /// Record the intent.
    ///
    /// Scheduling usually cannot happen here. On a fresh install
    /// notification permission is asked for *after* onboarding closes, and
    /// calling `schedule` while the status is still undetermined would put
    /// the bare system dialog on screen ahead of the app's own explainer —
    /// which is the whole thing `NotificationPermission` exists to avoid.
    /// So the intent is persisted and flushed when the answer arrives.
    static func armWatchNudge(mediaID: Int, mediaType: String, title: String) async {
        pendingNudge = WatchNudge(mediaID: mediaID,
                                  mediaType: mediaType,
                                  title: title,
                                  due: Date().addingTimeInterval(nudgeDelay))
        await flushWatchNudge()
    }

    /// Schedule the pending nudge, if there is one and it is still worth
    /// sending. Safe to call as often as you like.
    static func flushWatchNudge() async {
        guard let nudge = pendingNudge else { return }

        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            break
        case .notDetermined:
            // Still unanswered. Leave the intent alone — this gets called
            // again the moment the user says yes.
            return
        default:
            // Denied. There is nothing to wait for, so stop holding it.
            pendingNudge = nil
            return
        }

        // They have had three days to watch it or drop it, and either
        // answer makes the nudge noise.
        guard WatchlistManager.watchlist.contains(where: { $0.id == nudge.mediaID }),
              !WatchedStore.isWatched(nudge.mediaID)
        else {
            pendingNudge = nil
            return
        }

        await schedule(identifier: nudgeIdentifier(mediaID: nudge.mediaID),
                       title: "Ready when you are",
                       body: "\(nudge.title) is on a service you have. Fancy it tonight?",
                       on: nudge.due,
                       atHour: nudgeHour,
                       deepLink: DeepLink(id: nudge.mediaID,
                                          mediaType: nudge.mediaType == "tv" ? .tv : .movie),
                       // The delay *is* this notification. A debug build
                       // collapsing it to three seconds turns it into the
                       // instant "you just saved these" alert it exists to
                       // avoid being.
                       debugFiresImmediately: false)
        pendingNudge = nil
    }

    // MARK: - Helpers

    /// TMDB release/air dates are date-only — pin the fire time to a
    /// sensible hour so the notification arrives at a reasonable time of day
    /// instead of at midnight.
    private static func fireDate(for date: Date, atHour hour: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        comps.hour = hour
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? date
    }

}

// MARK: - Foreground delegate

/// Allows notification banners to display while the app is in the
/// foreground. Without this, iOS silently delivers the notification to
/// the notification center without showing the banner, which makes
/// previewing the styling impossible during development.
final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {

    static let shared = NotificationCenterDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }

    /// Called when the user taps a notification (banner or notification
    /// centre entry). Decodes the userInfo into a `DeepLink` and hands it
    /// to the router so the SwiftUI tree can push the relevant details
    /// screen.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let deeplink = DeepLinkRouter.decode(userInfo: userInfo) {
            Task { @MainActor in
                DeepLinkRouter.shared.handle(deeplink)
            }
        }
        completionHandler()
    }
}
