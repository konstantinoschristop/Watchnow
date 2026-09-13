//
//  BackgroundRefresh.swift
//  Watchnow
//
//  The app's first background work, and the one place the alerts pipeline is
//  driven from.
//
//  Everything stays on device. Episode air dates are known in advance from
//  TMDB, so the alerts for them can be scheduled locally and iOS delivers
//  them whether or not the app ever runs again. This task exists to keep
//  that schedule current: it lets `WatchlistChangeMonitor` refresh what it
//  knows, re-plans from the result, and reconciles. Missing a run costs
//  freshness, never correctness — the same pipeline runs on every launch.
//
//  Two rules that are not negotiable, because iOS stops giving background
//  time to apps that break them: always call `setTaskCompleted`, on every
//  path including failure and expiration; and always submit the next request
//  before finishing, since a task that never reschedules never runs again.
//

import Foundation
import BackgroundTasks

@MainActor
enum BackgroundRefresh {

    /// Must match `BGTaskSchedulerPermittedIdentifiers` in Info.plist. iOS
    /// refuses to register an identifier that isn't declared there, and does
    /// it by trapping, so a typo here is a launch crash rather than a silent
    /// no-op.
    /// `nonisolated` because `register()` has to be callable before the
    /// main actor is the place we are — it runs from `WatchnowApp.init`.
    nonisolated static let taskIdentifier = "k.christopoulos.Watchnow.refresh"

    /// The practical ceiling on a `BGAppRefreshTask`. iOS grants around 30
    /// seconds; finishing well inside that is how an app keeps being asked
    /// back.
    static let budget: TimeInterval = 20

    /// The soonest the next run may happen. A watchlist does not change by
    /// the minute, and asking too often is the fastest way to be deprioritised.
    static let minimumGap: TimeInterval = 4 * 3600

    // MARK: - Registration

    /// Register the task handler. Must run before the app finishes
    /// launching, which for a SwiftUI lifecycle means `WatchnowApp.init`.
    nonisolated static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier,
                                        using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            let box = TaskBox(refreshTask)
            Task { @MainActor in await run(box) }
        }
    }

    /// `BGAppRefreshTask` isn't `Sendable`, and the pipeline it drives runs
    /// on the main actor. iOS hands the task over on one queue and only ever
    /// expects `expirationHandler` and `setTaskCompleted` on it, so carrying
    /// it across in a box is honest about the narrowness of that contract —
    /// the same `@unchecked Sendable` bargain `ServiceInvocation` and
    /// `NotificationCenterDelegate` already make.
    private final class TaskBox: @unchecked Sendable {
        let task: BGAppRefreshTask
        init(_ task: BGAppRefreshTask) { self.task = task }
    }

    /// Ask iOS for another run. Cheap and idempotent — submitting while a
    /// request is already queued just replaces it.
    static func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: minimumGap)
        // Throws on the simulator, and whenever the user has switched
        // Background App Refresh off. Neither is an error worth surfacing:
        // the foreground pass keeps the schedule correct either way.
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - The background pass

    private static func run(_ box: TaskBox) async {
        // Queue the next run first. If the work below throws, hangs or is
        // killed, the chain still continues.
        scheduleNext()

        let work = Task { @MainActor in
            await WatchlistChangeMonitor.syncIfNeeded()
            return await replan()
        }

        // iOS calls this when our time is up. Cancelling lets the monitor's
        // `Task.isCancelled` checks unwind mid-batch instead of being
        // killed outright.
        box.task.expirationHandler = { work.cancel() }

        // A second guard for the case iOS is more generous than we want to
        // be: finish inside our own budget rather than lingering.
        let timeout = Task { @MainActor in
            try? await Task.sleep(for: .seconds(budget))
            work.cancel()
        }

        _ = await work.value
        timeout.cancel()
        box.task.setTaskCompleted(success: !work.isCancelled)
    }

    // MARK: - The foreground pass

    /// Re-plan on launch and on every return to the foreground.
    ///
    /// Deliberately does not sync: `WhatsNewViewModel.checkOnLaunch` already
    /// drives `WatchlistChangeMonitor` on exactly these moments, and running
    /// a second sync beside it would double every title's request count for
    /// no new information. This takes whatever the monitor last learned and
    /// makes the schedule agree with it.
    @discardableResult
    static func runForegroundPass() async -> AlertScheduler.Outcome {
        scheduleNext()
        return await replan()
    }

    // MARK: - Plan and reconcile

    /// Read the stores, plan, and make iOS match. The whole pipeline in four
    /// lines, which is the point of keeping the pieces pure.
    @discardableResult
    static func replan(using client: any NotificationCenterClient = LiveNotificationCenterClient()
    ) async -> AlertScheduler.Outcome {

        let manualReminders = AlertInputs.manualReminders(from: await client.pending())
        let plan = AlertPlanner.plan(episodes: AlertInputs.episodeEvents(),
                                     manualReminders: manualReminders)
        return await AlertScheduler.reconcile(plan, using: client)
    }

    #if DEBUG
    /// Everything the background task does, minus iOS deciding when.
    ///
    /// Forces the sync rather than honouring `WatchlistChangeMonitor`'s
    /// twelve-hour gap: a title saved a minute ago has no snapshot yet, so
    /// without this the debug menu would report an empty plan and be
    /// perfectly right about nothing.
    @discardableResult
    static func runDebugPass() async -> AlertScheduler.Outcome {
        await WatchlistChangeMonitor.syncIfNeeded(force: true)
        return await replan()
    }
    #endif

    /// The plan as it stands, without touching iOS. For the debug menu.
    static func currentPlan(using client: any NotificationCenterClient = LiveNotificationCenterClient()
    ) async -> [PlannedAlert] {
        AlertPlanner.plan(episodes: AlertInputs.episodeEvents(),
                          manualReminders: AlertInputs.manualReminders(from: await client.pending()))
    }
}
