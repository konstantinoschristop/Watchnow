//
//  ReviewRequestManager.swift
//  Watchnow
//
//  Spends the App Store review prompt, at most once every four months.
//
//  `ReviewPromptPolicy` decides whether to ask; this owns the bookkeeping
//  and the one call to StoreKit. It replaces a once-per-version rule that
//  fired on the third save alone — the store had no ratings under it, and
//  a save is the moment someone starts work rather than finishes it.
//

import Foundation
import StoreKit
import UIKit

@MainActor
enum ReviewRequestManager {

    private enum Key {
        static let savedCount = "review.qualifyingActionCount"
        static let firstSeen = "review.firstSeenDate"
        static let lastPromptedAt = "review.lastPromptedAt"
        /// The old once-per-version marker. Read once during migration,
        /// never written again.
        static let legacyPromptedVersion = "review.lastPromptedVersion"
    }

    /// Lets the success toast and haptic finish before the system sheet
    /// slides up. Landing on top of a toast reads as an ambush.
    private static let presentationDelay: TimeInterval = 1.5

    /// True for the session that created the install record. Transient by
    /// design — a relaunch is a second session.
    private static var isFirstSession = false

    // MARK: - Launch bookkeeping

    /// Call once per launch, before anything can trigger a prompt.
    static func recordLaunch(now: Date = Date()) {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Key.firstSeen) == nil {
            defaults.set(now, forKey: Key.firstSeen)
            isFirstSession = true
        }
        migrateLegacyPromptMarkerIfNeeded(now: now)
    }

    /// v2.0 recorded only *which version* last prompted, so an upgrading
    /// user carries no date. Treat a marker matching the running version as
    /// "prompted just now" and start the four-month clock from here: asking
    /// again immediately is the one outcome worth ruling out, and being
    /// four months late costs nothing.
    private static func migrateLegacyPromptMarkerIfNeeded(now: Date) {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Key.lastPromptedAt) == nil,
              let legacy = defaults.string(forKey: Key.legacyPromptedVersion)
        else { return }

        if legacy == currentAppVersion() {
            defaults.set(now, forKey: Key.lastPromptedAt)
        }
        defaults.removeObject(forKey: Key.legacyPromptedVersion)
    }

    // MARK: - Counting

    static func recordWatchlistAdd() {
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: Key.savedCount) + 1, forKey: Key.savedCount)
    }

    // MARK: - Asking

    /// Ask, if this moment has earned it. Safe to call from any trigger
    /// site — the policy does the deciding.
    static func requestReview(for trigger: ReviewTrigger, now: Date = Date()) {
        let defaults = UserDefaults.standard
        let inputs = ReviewPromptPolicy.Inputs(
            trigger: trigger,
            firstLaunchedAt: defaults.object(forKey: Key.firstSeen) as? Date,
            lastPromptedAt: defaults.object(forKey: Key.lastPromptedAt) as? Date,
            isFirstSession: isFirstSession,
            savedCount: defaults.integer(forKey: Key.savedCount),
            watchedCount: WatchedStore.count,
            now: now)

        guard ReviewPromptPolicy.shouldAsk(inputs) else { return }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(presentationDelay))
            guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            else { return }

            AppStore.requestReview(in: scene)
            UserDefaults.standard.set(now, forKey: Key.lastPromptedAt)
        }
    }

    private static func currentAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    // MARK: - Reset

    /// Debug tooling and tests only.
    static func reset() {
        let defaults = UserDefaults.standard
        for key in [Key.savedCount, Key.firstSeen, Key.lastPromptedAt, Key.legacyPromptedVersion] {
            defaults.removeObject(forKey: key)
        }
        isFirstSession = false
    }
}
