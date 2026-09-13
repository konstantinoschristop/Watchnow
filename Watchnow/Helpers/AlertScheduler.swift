//
//  AlertScheduler.swift
//  Watchnow
//
//  Makes what iOS holds match what `AlertPlanner` decided.
//
//  The whole design goal is that running it twice changes nothing the second
//  time: it adds what is planned but missing, removes what is scheduled but
//  no longer planned, and leaves everything else alone. That is what lets it
//  be called on every launch and every background refresh without the
//  schedule drifting.
//
//  It only ever touches identifiers under `auto.` — the reminders the user
//  set by hand with the bell live under `reminder.` and are none of its
//  business.
//

import Foundation

@MainActor
enum AlertScheduler {

    /// What a reconcile actually did. Returned rather than logged so the
    /// debug menu can show it and tests can assert on it.
    struct Outcome: Equatable {
        /// The alerts iOS accepted this pass. Carried rather than counted so
        /// the caller can mark their source changes as alerted — and only
        /// the ones that genuinely landed.
        var addedAlerts: [PlannedAlert] = []
        var removedIdentifiers: [String] = []
        /// True when nothing was attempted because iOS wouldn't deliver
        /// anyway. Distinct from "nothing needed doing".
        var skippedUnauthorized: Bool = false

        var added: Int { addedAlerts.count }
        var removed: Int { removedIdentifiers.count }

        static let unauthorized = Outcome(skippedUnauthorized: true)
    }

    /// The pure core: what to add, and what to take away.
    ///
    /// `existing` is every pending identifier iOS holds, ours and the user's
    /// alike — the filtering to `auto.` happens here so no caller has to
    /// remember to do it.
    nonisolated static func diff(plan: [PlannedAlert],
                                 existing: [String]) -> (add: [PlannedAlert], remove: [String]) {
        let ours = Set(existing.filter { $0.hasPrefix(AlertPlanner.autoPrefix) })
        let planned = Set(plan.map(\.identifier))

        return (add: plan.filter { !ours.contains($0.identifier) },
                remove: ours.subtracting(planned).sorted())
    }

    /// Bring iOS in line with `plan`.
    @discardableResult
    static func reconcile(_ plan: [PlannedAlert],
                          using client: any NotificationCenterClient = LiveNotificationCenterClient()
    ) async -> Outcome {

        // Nothing would be delivered, so nothing is worth scheduling. The
        // existing requests are left untouched rather than torn down: if the
        // user turns notifications back on, the next reconcile finds the
        // schedule already correct instead of rebuilding it from nothing.
        let status = await client.authorizationStatus()
        switch status {
        case .authorized, .provisional, .ephemeral: break
        default: return .unauthorized
        }

        let existing = await client.pending().map(\.identifier)
        let work = diff(plan: plan, existing: existing)

        await client.removePending(identifiers: work.remove)

        var accepted: [PlannedAlert] = []
        for alert in work.add {
            do {
                try await client.add(alert)
                accepted.append(alert)
            } catch {
                // A rejected request is not worth failing the whole pass
                // for — the next reconcile will try it again.
                continue
            }
        }

        return Outcome(addedAlerts: accepted, removedIdentifiers: work.remove)
    }
}
