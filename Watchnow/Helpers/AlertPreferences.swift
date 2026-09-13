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
        didShowPermissionExplainer = false
    }
}
