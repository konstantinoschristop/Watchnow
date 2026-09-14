//
//  NotificationPermission.swift
//  Watchnow
//
//  The single place the app asks iOS for permission to send notifications,
//  and the only thing that decides when to ask.
//
//  Two rules shape it:
//
//   1. Never at launch. The prompt appears after the user's first save,
//      when "we'll tell you the moment it airs" is a promise about
//      something they just chose rather than an abstract request from a
//      screen they haven't used yet.
//   2. Never twice. The explainer is shown at most once per device, and a
//      denial is respected in silence — `AlertPreferences.
//      didShowPermissionExplainer` is set on *both* the accept and the
//      decline path, so there is no route back to the system prompt except
//      the Settings app.
//
//  The system prompt itself is still `ReminderManager.requestAuthorization()`
//  — the same call the bell reminders have used since v1.3. This type adds
//  the explainer in front of it and the bookkeeping around it; it does not
//  open a second pipeline.
//
//  A shared `ObservableObject` (like `DeepLinkRouter`) because the save that
//  triggers it happens on a details screen or in a list row, while the sheet
//  that explains it belongs to the app's root — the two can't reach each
//  other any other way.
//

import Foundation
import UserNotifications

@MainActor
final class NotificationPermission: ObservableObject {

    static let shared = NotificationPermission()

    /// Drives the explainer sheet hosted by `ContentView`.
    @Published var explainerPresented = false

    /// Last known authorization status. Refreshed on demand rather than
    /// observed, because iOS has no change notification for it — the user
    /// can only alter it in Settings, which means leaving and re-entering
    /// the app.
    @Published private(set) var status: UNAuthorizationStatus = .notDetermined

    /// Lets the "Added to Watchlist" toast land before the sheet slides up.
    /// Same reasoning as `ReviewRequestManager`'s deferral, shorter because
    /// this one is part of the same gesture rather than an interruption.
    private static let presentationDelay: Duration = .milliseconds(800)

    private init() {}

    // MARK: - Status

    var isAuthorized: Bool {
        switch status {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    /// True when iOS will still show a system prompt if we ask.
    var canStillAsk: Bool { status == .notDetermined }

    @discardableResult
    func refreshStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        status = settings.authorizationStatus

        // Authorization can be granted without this app ever asking — the
        // user declines the explainer, then turns notifications on in iOS
        // Settings. Hooking the flush to the places we *ask* missed that
        // entirely and left onboarding's watch nudge persisted but never
        // scheduled. This is the one place guaranteed to observe the new
        // status, and `flushWatchNudge` is a no-op unless something is
        // actually pending.
        if status == .authorized {
            await ReminderManager.flushWatchNudge()
        }
        return status
    }

    // MARK: - The first-save moment

    /// Offer the explainer if this is the first save on a device that has
    /// never been asked. Safe to call on every save: it is a no-op once the
    /// explainer has been shown, and a no-op when iOS has already been
    /// answered (typically by a bell reminder set before this release).
    func offerAfterSave() async {
        await offer()
    }

    /// The other moment worth asking: onboarding has just filled the
    /// watchlist, so "we'll tell you the moment it airs" is a promise about
    /// three titles the user chose thirty seconds ago.
    func offerAfterOnboarding() async {
        await offer()
    }

    private func offer() async {
        await refreshStatus()
        guard canStillAsk, !AlertPreferences.didShowPermissionExplainer else { return }

        try? await Task.sleep(for: Self.presentationDelay)
        guard !Task.isCancelled else { return }
        explainerPresented = true
    }

    // MARK: - Explainer outcomes

    /// The user said yes to us; now ask iOS. Marking the explainer as shown
    /// *before* the system prompt is deliberate — if the app dies while the
    /// prompt is up, the user has still seen our explanation and iOS has
    /// still recorded its own answer, so re-showing it would only be noise.
    func acceptExplainer() async {
        AlertPreferences.didShowPermissionExplainer = true
        explainerPresented = false
        _ = await ReminderManager.requestAuthorization()
        // Refreshing is what flushes any watch nudge onboarding left
        // waiting on this answer — see `refreshStatus`.
        await refreshStatus()
    }

    /// The user said "not now". No system prompt, no second attempt, no
    /// nagging later — the Settings screen is the only way back.
    func declineExplainer() {
        AlertPreferences.didShowPermissionExplainer = true
        explainerPresented = false
    }

    // MARK: - Settings entry point

    /// Ask from the Settings screen, where the user came looking for it.
    /// Falls through to the system Settings app once iOS has been answered,
    /// because at that point we can no longer prompt.
    func requestFromSettings() async {
        await refreshStatus()
        if canStillAsk {
            AlertPreferences.didShowPermissionExplainer = true
            _ = await ReminderManager.requestAuthorization()
            await refreshStatus()
        } else {
            ReminderManager.openNotificationSettings()
        }
    }
}
