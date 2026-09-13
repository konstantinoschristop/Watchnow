//
//  OnboardingGate.swift
//  Watchnow
//
//  Decides whether a launch is a first launch.
//
//  The hard case is not the fresh install — it is the *second device*. A
//  user who reinstalls, or signs in on an iPad, has a watchlist waiting in
//  iCloud, but for the first seconds after launch the local store is empty
//  and looks exactly like a brand-new user. Showing onboarding to someone
//  with four years of saved films is the worst first impression this release
//  could make, so the gate waits a moment before concluding anything.
//
//  What it waits *on* is shaped by how this app syncs. There is no CloudKit
//  import to observe: `CloudSync` mirrors `NSUbiquitousKeyValueStore`, whose
//  only signal is `didMergeRemoteChanges`. So the gate takes "has a merge
//  carrying the watchlist landed yet?" and a stopwatch, and answers with one
//  of three words. Pure — the caller owns the clock and the observer.
//

import Foundation

enum OnboardingGate {

    /// How long to wait for iCloud before deciding the user is genuinely
    /// new. Long enough for a merge on a decent connection, short enough
    /// that a fresh install doesn't feel stalled.
    static let restoreTimeout: TimeInterval = 3

    enum Decision: Equatable {
        /// Genuinely a new user — run the three steps.
        case show
        /// Data may still be arriving; hold, showing the app shell behind a
        /// quiet "Restoring your watchlist…".
        case wait
        /// Nothing to do. Either they have been here before, or their
        /// watchlist just arrived.
        case skip
    }

    struct Inputs: Equatable {
        var hasCompletedOnboarding: Bool
        var watchlistCount: Int
        /// Whether the device is signed into iCloud at all. When it isn't,
        /// nothing can arrive and there is nothing to wait for.
        var isCloudAvailable: Bool
        /// A remote merge carrying the watchlist key has been observed.
        var didMergeWatchlist: Bool
        /// How long the caller has been waiting so far.
        var waited: TimeInterval

        init(hasCompletedOnboarding: Bool,
             watchlistCount: Int,
             isCloudAvailable: Bool,
             didMergeWatchlist: Bool = false,
             waited: TimeInterval = 0) {
            self.hasCompletedOnboarding = hasCompletedOnboarding
            self.watchlistCount = watchlistCount
            self.isCloudAvailable = isCloudAvailable
            self.didMergeWatchlist = didMergeWatchlist
            self.waited = waited
        }
    }

    static func decide(_ inputs: Inputs) -> Decision {
        // Been here before — on this device or any other, since the flag
        // syncs.
        if inputs.hasCompletedOnboarding { return .skip }

        // Data exists. Whether it was always here or just landed from
        // iCloud, this is not a new user and there is nothing to set up.
        if inputs.watchlistCount > 0 { return .skip }

        // Not signed into iCloud, so an empty store is the whole truth and
        // waiting would only stall a genuinely new user.
        guard inputs.isCloudAvailable else { return .show }

        // A merge landed and the watchlist is *still* empty: iCloud has
        // spoken and it had nothing. That is a real new user, and waiting
        // out the rest of the timeout would be for nothing.
        if inputs.didMergeWatchlist { return .show }

        return inputs.waited >= restoreTimeout ? .show : .wait
    }
}
