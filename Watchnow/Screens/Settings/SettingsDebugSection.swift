//
//  SettingsDebugSection.swift
//  Watchnow
//
//  Developer bench for the alerts pipeline. Compiles away entirely in
//  Release.
//
//  It exists because almost nothing in this feature can be observed by using
//  the app normally: a plan is invisible, a reconcile is invisible, and the
//  soonest real episode alert might be nine days away. These buttons make
//  each step of `refresh → plan → reconcile` show its work, so a change to
//  the caps or the quiet hours can be checked on a device in seconds rather
//  than by waiting for Thursday.
//

#if DEBUG

import SwiftUI
import UserNotifications

struct SettingsDebugSection: View {

    @State private var status: String?
    @State private var lines: [String] = []
    @State private var isWorking = false

    var body: some View {
        Section {
            Button("Run refresh + plan now") { run(runRefresh) }
            Button("Show planned alerts") { run(showPlan) }
            Button("Show pending notifications") { run(showPending) }
            Button("Fire sample alert") { run(fireSample) }
            Button("Reset alert preferences", role: .destructive) {
                // Also clears the alerted-change ledger, so a "now
                // streaming" change can be offered again for testing.
                AlertPreferences.reset()
                status = "Alert preferences and alerted-change ledger reset"
                lines = []
            }
            Button("Reset onboarding", role: .destructive) {
                OnboardingState.reset()
                status = "Onboarding will run again on next launch"
                lines = []
            }
            Button("Mark all as unwatched", role: .destructive) {
                WatchedStore.reset()
                status = "Watched state cleared"
                lines = []
            }

            if let status {
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Developer")
        } footer: {
            Text("Debug builds only. Note that manual bell reminders fire ~3s after being set in Debug, so their dates here are not the real ones.")
        }
        .disabled(isWorking)
    }

    // MARK: - Actions

    private func run(_ work: @escaping () async -> Void) {
        guard !isWorking else { return }
        isWorking = true
        Task {
            await work()
            isWorking = false
        }
    }

    private func runRefresh() async {
        status = "Syncing the watchlist, then planning…"
        lines = []
        let outcome = await BackgroundRefresh.runDebugPass()
        status = outcome.skippedUnauthorized
            ? "Skipped — notifications not authorized"
            : "Reconciled: +\(outcome.added) / −\(outcome.removed)"
    }

    private func showPlan() async {
        // Report the inputs alongside the output. An empty plan is usually
        // correct — nothing dated, everything already aired, a cap doing its
        // job — and without the left-hand side of the arrow there is no way
        // to tell which of those it was.
        let events = AlertInputs.episodeEvents()
        let landed = AlertInputs.streamingChanges()
        let plan = await BackgroundRefresh.currentPlan()
        status = "\(events.count) dated · \(landed.count) streaming → "
            + "\(plan.count) planned (cap \(AlertPlanner.maxPending))"

        if !plan.isEmpty {
            lines = plan.map { "\(Self.stamp($0.fireDate))  \($0.body)" }
        } else if events.isEmpty && landed.isEmpty {
            lines = ["Nothing to plan: no dated next episode, and nothing new",
                     "on a service you have. Services live in Movie Night setup."]
        } else {
            lines = events.map { event in
                "skipped  \(event.seriesTitle) — airs \(Self.stamp(event.airDate))"
            } + landed.map { change in
                "skipped  \(change.title) — capped or muted"
            }
        }
    }

    private func showPending() async {
        let pending = await LiveNotificationCenterClient().pending()
            .sorted { ($0.fireDate ?? .distantFuture) < ($1.fireDate ?? .distantFuture) }
        let auto = pending.filter { $0.identifier.hasPrefix(AlertPlanner.autoPrefix) }.count
        status = "\(pending.count) pending with iOS — \(auto) ours, \(pending.count - auto) manual"
        lines = pending.map { "\(Self.stamp($0.fireDate))  \($0.identifier)" }
    }

    /// Goes around the planner on purpose: this checks that content, sound
    /// and the deep-link payload survive a real delivery, which is the one
    /// thing the unit tests cannot cover.
    private func fireSample() async {
        guard await NotificationPermission.shared.refreshStatus() == .authorized else {
            status = "Not authorized — turn notifications on first"
            return
        }
        let first = WatchlistManager.watchlist.first(where: { $0.id != nil })
        let content = UNMutableNotificationContent()
        content.title = "New episode"
        content.body = first.map { "\($0.getResultTitle()) S1E1 airs today" }
            ?? "Sample alert — nothing saved yet"
        content.sound = .default
        if let id = first?.id {
            let type: DeepLink.MediaType = first?.inferredScreenType == .tv ? .tv : .movie
            content.userInfo = DeepLink(id: id, mediaType: type).userInfo
        }

        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "debug.sample.\(UUID().uuidString)",
                                  content: content,
                                  trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5,
                                                                             repeats: false)))
        status = "Sample alert fires in 5s — background the app to see the banner"
        lines = []
    }

    private static func stamp(_ date: Date?) -> String {
        guard let date else { return "  —  " }
        let fmt = DateFormatter()
        fmt.dateFormat = "dd MMM HH:mm"
        return fmt.string(from: date)
    }
}

#endif
