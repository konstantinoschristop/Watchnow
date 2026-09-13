//
//  AlertPreferences.swift
//  Watchnow
//
//  What the user has said about automatic alerts: two global switches and
//  a set of per-title exceptions.
//
//  It stores *opt-outs*, never follows. Saving a title subscribes you by
//  design, so a stored "following" flag would be a second copy of the
//  watchlist — and a treacherous one over iCloud's key-value store. Picture
//  a phone that saves a title and writes the flag, and an iPad holding the
//  same title from an older sync with no flag: last-writer-wins would then
//  decide whether the user hears about it at all. An exception set has no
//  such ambiguity, because absent means the default and the default is the
//  same answer on every device.
//
//  Persisted with the `@UserDefault` wrapper the watchlist uses and mirrored
//  to iCloud — an alert switched off on the phone should stay off on the
//  iPad. The permission bookkeeping at the bottom is the exception: it
//  describes this device's relationship with iOS, so it stays local.
//

import Foundation

@MainActor
enum AlertPreferences {

    // MARK: - Global switches

    /// "Tell me when the next episode of a series I saved airs."
    @UserDefault("alertsEpisodesEnabled", defaultValue: true)
    static var episodeAlertsEnabled: Bool

    /// "Tell me when something I saved lands on a service I have."
    @UserDefault("alertsStreamingEnabled", defaultValue: true)
    static var streamingAlertsEnabled: Bool

    // MARK: - Per-title exceptions

    /// TMDB ids the user has explicitly muted. Array rather than `Set` to
    /// match `TasteProfile.likedIDs` and the rest of the persisted id lists.
    @UserDefault("alertsOptedOutIDs", defaultValue: [])
    private static var optedOutIDs: [Int]

    static func isOptedOut(_ id: Int) -> Bool {
        optedOutIDs.contains(id)
    }

    static func setOptedOut(_ optedOut: Bool, for id: Int) {
        if optedOut {
            guard !optedOutIDs.contains(id) else { return }
            optedOutIDs.append(id)
        } else {
            guard optedOutIDs.contains(id) else { return }
            optedOutIDs.removeAll { $0 == id }
        }
    }

    /// Everything the two switches and this title's exception currently say,
    /// packaged for `AutoAlertPolicy`. The policy stays pure by never
    /// reading a store; this is the one place that bridges the two.
    static func policyInputs(forID id: Int, isSaved: Bool) -> AutoAlertPolicy.Inputs {
        AutoAlertPolicy.Inputs(isSaved: isSaved,
                               episodeAlertsEnabled: episodeAlertsEnabled,
                               streamingAlertsEnabled: streamingAlertsEnabled,
                               isOptedOut: isOptedOut(id))
    }

    /// Drop a title's exception when it leaves the watchlist, so re-saving
    /// later starts from the default rather than from a decision made about
    /// a different moment. Mirrors how `addedDates` and `providers` are
    /// forgotten in `WatchlistManager.removeFromWatchList`.
    static func forget(resultID id: Int) {
        setOptedOut(false, for: id)
    }

    // MARK: - Alerted-change ledger

    /// `WatchlistChange` ids already sent as a notification.
    ///
    /// Without this, a "now streaming" alert would be re-sent on every run
    /// until the user happened to open the app and spend the change: the
    /// reconcile is idempotent only while the notification is still pending,
    /// and once it has *fired* it is no longer pending, so the next plan
    /// would cheerfully schedule it again.
    ///
    /// Device-local, deliberately. Notifications are delivered per device,
    /// so being told once on the phone should not silence the iPad the user
    /// actually picks up. Same reasoning that keeps What's New's seen-state
    /// off iCloud.
    @UserDefault("alertsNotifiedChangeIDs", defaultValue: [])
    private static var notifiedChangeIDs: [String]

    /// Ceiling on the ledger. Changes age out of `WatchlistChangeStore`
    /// after 30 days, so an id older than the last few hundred can never be
    /// offered again anyway.
    private static let maxNotifiedIDs = 300

    static var alertedChangeIDs: Set<String> { Set(notifiedChangeIDs) }

    static func recordAlerted(changeIDs: [String]) {
        guard !changeIDs.isEmpty else { return }
        let known = Set(notifiedChangeIDs)
        let fresh = changeIDs.filter { !known.contains($0) }
        guard !fresh.isEmpty else { return }
        notifiedChangeIDs = Array((notifiedChangeIDs + fresh).suffix(maxNotifiedIDs))
    }

    // MARK: - Device-local bookkeeping

    /// Whether the pre-permission explainer has already been shown here.
    /// Deliberately not synced: notification authorization is granted per
    /// device, so the explanation belongs to the device too. It is also what
    /// guarantees the explainer is shown at most once — including after a
    /// denial, which must never be re-prompted.
    @UserDefault("alertsDidShowPermissionExplainer", defaultValue: false)
    static var didShowPermissionExplainer: Bool

    // MARK: - Reset

    /// Wipe everything — debug tooling and tests only.
    static func reset() {
        episodeAlertsEnabled = true
        streamingAlertsEnabled = true
        optedOutIDs = []
        notifiedChangeIDs = []
        didShowPermissionExplainer = false
    }
}
