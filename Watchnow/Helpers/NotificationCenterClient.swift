//
//  NotificationCenterClient.swift
//  Watchnow
//
//  The seam between `AlertScheduler` and `UNUserNotificationCenter`.
//
//  It exists for exactly one reason: scheduling is the only part of the
//  alerts pipeline that cannot be a pure function, so it is the only part
//  that gets a protocol. Everything above it — the planner, the policy —
//  works on value types and needs no fake. Keep it that way; a protocol per
//  layer is how a small app acquires an architecture nobody asked for.
//

import Foundation
import UserNotifications

/// A notification iOS already holds, reduced to the two things the app needs
/// to reason about it.
struct PendingRequest: Equatable, Sendable {
    let identifier: String
    /// When it will fire, or nil for a trigger that can't say.
    let fireDate: Date?
}

protocol NotificationCenterClient: Sendable {
    func authorizationStatus() async -> UNAuthorizationStatus
    func pending() async -> [PendingRequest]
    func add(_ alert: PlannedAlert) async throws
    func removePending(identifiers: [String]) async
}

// MARK: - Live

struct LiveNotificationCenterClient: NotificationCenterClient {

    private var center: UNUserNotificationCenter { .current() }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func pending() async -> [PendingRequest] {
        await center.pendingNotificationRequests().map { request in
            PendingRequest(identifier: request.identifier,
                           fireDate: Self.fireDate(of: request.trigger))
        }
    }

    func add(_ alert: PlannedAlert) async throws {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.body
        content.sound = .default
        content.userInfo = alert.deepLink.userInfo

        // Deliberately a calendar trigger on the real date, with none of the
        // DEBUG "fire in 3 seconds" shortcut `ReminderManager.schedule` uses.
        // Reconciling against pending requests only makes sense when the
        // pending dates are the ones that were planned; the debug menu is
        // where a notification gets fired on demand instead.
        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: alert.fireDate)

        let request = UNNotificationRequest(
            identifier: alert.identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))

        try await center.add(request)
    }

    func removePending(identifiers: [String]) async {
        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private static func fireDate(of trigger: UNNotificationTrigger?) -> Date? {
        switch trigger {
        case let calendar as UNCalendarNotificationTrigger:  return calendar.nextTriggerDate()
        case let interval as UNTimeIntervalNotificationTrigger: return interval.nextTriggerDate()
        default: return nil
        }
    }
}
