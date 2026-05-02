//
//  ReviewRequestManager.swift
//  Watchnow
//
//  Decides when to ask the user for an App Store review.
//
//  Strategy: prompt at most once per app version, after the user has shown
//  engagement (N watchlist adds) and the app has been installed for at
//  least a couple of days. Apple's own throttle (3 prompts / 365 days)
//  sits on top of this as a backstop — these gates exist to make sure we
//  ask in a "this app is useful" moment rather than burning the quota
//  early.
//

import Foundation
import StoreKit
import UIKit

@MainActor
enum ReviewRequestManager {

    private enum Key {
        static let qualifyingActionCount = "review.qualifyingActionCount"
        static let lastPromptedVersion = "review.lastPromptedVersion"
        static let firstSeenDate = "review.firstSeenDate"
    }

    private static let actionThreshold = 3
    private static let minDaysSinceFirstSeen = 2

    static func recordWatchlistAdd() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Key.firstSeenDate) == nil {
            defaults.set(Date(), forKey: Key.firstSeenDate)
        }
        let next = defaults.integer(forKey: Key.qualifyingActionCount) + 1
        defaults.set(next, forKey: Key.qualifyingActionCount)
    }

    static func requestReviewIfAppropriate() {
        guard shouldRequestReview() else { return }

        // Defer so the success haptic + toast finish first; the system
        // sheet appearing on top of the toast feels jarring otherwise.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            else { return }

            Task { await AppStore.requestReview(in: scene) }
            UserDefaults.standard.set(currentAppVersion(), forKey: Key.lastPromptedVersion)
        }
    }

    private static func shouldRequestReview() -> Bool {
        let defaults = UserDefaults.standard

        guard defaults.integer(forKey: Key.qualifyingActionCount) >= actionThreshold else {
            return false
        }

        if let lastVersion = defaults.string(forKey: Key.lastPromptedVersion),
           lastVersion == currentAppVersion() {
            return false
        }

        if let firstSeen = defaults.object(forKey: Key.firstSeenDate) as? Date {
            let elapsed = Date().timeIntervalSince(firstSeen)
            guard elapsed >= TimeInterval(minDaysSinceFirstSeen * 86_400) else { return false }
        }

        return true
    }

    private static func currentAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }
}
