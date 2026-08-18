//
//  InterstitialAdManager.swift
//  Watchnow
//
//  The app's single fullscreen ad, shown only when a Movie Night session
//  completes — the one place in WatchNow with a genuine "you're done" moment.
//
//  Deliberate constraints, because interstitials are the fastest way to make
//  an app feel spammy:
//
//   - Only fires at a completion boundary. Never on launch, never when
//     opening a title, never over a trailer, never mid-browse.
//   - Frequency capped: at most one every few minutes, and a small hard cap
//     per app session.
//   - Never blocks. If no creative is ready the moment we ask, the user just
//     continues — we never make them wait on a load.
//   - Preloaded during the swipe phase so presenting is instant.
//
//  Standard AdMob interstitials carry their own close control, so the user
//  can always dismiss it.
//

import Foundation
import GoogleMobileAds
import UIKit

@MainActor
final class InterstitialAdManager: NSObject {

    static let shared = InterstitialAdManager()

    private enum AdUnit {
        #if DEBUG
        /// Google's public test interstitial — debug builds must never
        /// request live inventory.
        static let interstitial = "ca-app-pub-3940256099942544/1033173712"
        #else
        static let interstitial = "ca-app-pub-5275868523622377/4405132482"
        #endif
    }

    // MARK: Caps

    /// Minimum gap between two fullscreen ads.
    private let minimumInterval: TimeInterval = 3 * 60
    /// Hard ceiling for one run of the app.
    private let maxPerSession = 3

    private var ad: InterstitialAd?
    private var isLoading = false
    private var lastShownAt: Date?
    private var shownThisSession = 0

    private override init() { super.init() }

    // MARK: - Loading

    /// Fetch a creative ahead of the moment we want to show it. Safe to call
    /// repeatedly — it no-ops while one is already loaded or in flight.
    func preload() {
        guard ad == nil, !isLoading, shownThisSession < maxPerSession else { return }
        isLoading = true

        Task {
            defer { isLoading = false }
            do {
                let loaded = try await InterstitialAd.load(with: AdUnit.interstitial,
                                                           request: Request())
                loaded.fullScreenContentDelegate = self
                ad = loaded
            } catch {
                // No fill is normal — stay silent and simply don't show one.
                ad = nil
            }
        }
    }

    // MARK: - Presenting

    /// Whether the caps currently allow a fullscreen ad.
    private var isAllowed: Bool {
        guard shownThisSession < maxPerSession else { return false }
        guard let lastShownAt else { return true }
        return Date().timeIntervalSince(lastShownAt) >= minimumInterval
    }

    /// Show the ad if one is ready and the caps allow it. Returns without
    /// doing anything otherwise — the caller never waits.
    func presentIfAllowed() {
        guard isAllowed, let ad else {
            // Nothing to show now, but warm one up for next time.
            preload()
            return
        }
        ad.present(from: nil)
        lastShownAt = Date()
        shownThisSession += 1
        self.ad = nil
    }
}

// MARK: - FullScreenContentDelegate

extension InterstitialAdManager: FullScreenContentDelegate {

    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        self.ad = nil
        // Get the next one ready for a later session.
        preload()
    }

    func ad(_ ad: any FullScreenPresentingAd,
            didFailToPresentFullScreenContentWithError error: any Error) {
        self.ad = nil
        preload()
    }
}
