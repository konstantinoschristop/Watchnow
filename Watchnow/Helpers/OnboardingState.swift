//
//  OnboardingState.swift
//  Watchnow
//
//  Whether the three-step first run has been completed.
//
//  Synced, so it follows the user to their other devices: someone who set
//  up on their phone should not be asked again on their iPad, even before
//  the watchlist itself has finished arriving.
//
//  Deliberately not gated on *finishing* anything. Every step is skippable,
//  and a user who skips all three has still been through onboarding — they
//  said no, which is an answer. Asking again next launch would be the app
//  refusing to hear it.
//

import Foundation

@MainActor
enum OnboardingState {

    @UserDefault("hasCompletedOnboarding", defaultValue: false)
    static var hasCompleted: Bool

    /// Mark it done. Safe to call more than once.
    static func markCompleted() {
        guard !hasCompleted else { return }
        hasCompleted = true
    }

    /// Debug tooling and tests only.
    static func reset() {
        hasCompleted = false
    }
}
