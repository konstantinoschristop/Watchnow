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

    /// Schedule a one-shot local notification at 09:00 local on `date`.
    /// Returns false if authorization was denied, the date is in the
    /// past, or the OS rejected the request.
    @discardableResult
    static func schedule(identifier: String,
                         title: String,
                         body: String,
                         on date: Date,
                         deepLink: DeepLink? = nil) async -> Bool {

        guard await requestAuthorization() else { return false }

        let fireDate = fireDateAt9AM(for: date)
        guard fireDate > Date() else { return false }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let deepLink {
            content.userInfo = deepLink.userInfo
        }

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: identifier,
                                            content: content,
                                            trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
            if !scheduledIDs.contains(identifier) {
                scheduledIDs.append(identifier)
            }
            return true
        } catch {
            return false
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

    // MARK: - Debug

    /// Fires a sample reminder ~3 seconds from now so the developer can
    /// preview the banner / sound styling without waiting for a real
    /// release date. Requires `NotificationCenterDelegate` to be installed
    /// for the banner to appear while the app is foregrounded. Embeds a
    /// dummy deeplink (Dune: Part Two, TMDB id 693134) so tapping the
    /// banner exercises the deeplink path end-to-end.
    @discardableResult
    static func scheduleDebugTest() async -> Bool {
        guard await requestAuthorization() else { return false }

        let content = UNMutableNotificationContent()
        content.title = "Out now"
        content.body = "Dune: Part Two is out today — time to watch."
        content.sound = .default
        content.userInfo = DeepLink(id: 693134, mediaType: .movie).userInfo

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(
            identifier: "reminder.debug.\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            return false
        }
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
