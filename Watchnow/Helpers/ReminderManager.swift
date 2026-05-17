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

    /// Schedule a one-shot local notification at 09:00 local on `date`.
    /// Returns `.authorizationDenied` if the OS-level permission is off,
    /// `.failed` for past dates or rejected requests, `.scheduled` on
    /// success.
    @discardableResult
    static func schedule(identifier: String,
                         title: String,
                         body: String,
                         on date: Date,
                         deepLink: DeepLink? = nil) async -> ScheduleResult {

        guard await requestAuthorization() else { return .authorizationDenied }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let deepLink {
            content.userInfo = deepLink.userInfo
        }

        // Debug builds fire ~3s from scheduling regardless of `date`, so
        // deeplink wiring can be tested end-to-end without waiting for
        // real release/air dates. Release builds use the real date pinned
        // to 09:00 local.
        let trigger: UNNotificationTrigger
        #if DEBUG
        _ = date
        trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        #else
        let fireDate = fireDateAt9AM(for: date)
        guard fireDate > Date() else { return .failed }
        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        #endif

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

    // MARK: - Helpers

    /// TMDB release/air dates are date-only — pin the fire time to 09:00
    /// local so the notification arrives at a reasonable hour instead of
    /// midnight.
    private static func fireDateAt9AM(for date: Date) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        comps.hour = 9
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
