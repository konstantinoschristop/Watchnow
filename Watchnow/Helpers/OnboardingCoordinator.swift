//
//  OnboardingCoordinator.swift
//  Watchnow
//
//  Decides when the first run happens, and holds the app still while it
//  makes up its mind.
//
//  `OnboardingGate` answers the question; this supplies the clock and the
//  iCloud observer it needs, and owns the one piece of state the view tree
//  cares about. A shared object for the same reason `DeepLinkRouter` is one:
//  the decision is taken at launch, outside any view, and the sheet it
//  drives belongs to the app's root.
//

import Foundation
import Combine

@MainActor
final class OnboardingCoordinator: ObservableObject {

    static let shared = OnboardingCoordinator()

    @Published var isPresented = false

    /// True while the gate is waiting on iCloud. Drives the quiet
    /// "Restoring your watchlist…" caption, so the pause reads as the app
    /// looking after the user rather than as a hang.
    @Published private(set) var isRestoring = false

    /// How often to re-ask the gate while waiting. Short enough that a merge
    /// landing at 200ms isn't sat on for a second.
    private static let pollInterval: Duration = .milliseconds(150)

    /// Set by the iCloud observer — a merge carrying the watchlist has
    /// arrived, so iCloud has said everything it is going to say.
    private var didMergeWatchlist = false
    private var mergeObserver: (any NSObjectProtocol)?

    private init() {
        mergeObserver = NotificationCenter.default.addObserver(
            forName: CloudSync.didMergeRemoteChanges,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let keys = note.userInfo?[CloudSync.changedKeysKey] as? [String] ?? []
            guard keys.contains("watchlist") else { return }
            MainActor.assumeIsolated { self?.didMergeWatchlist = true }
        }
    }

    /// Run once per launch, *after* the consent form has had its turn.
    ///
    /// Two modals racing for the first second of a fresh install is a bad
    /// first impression, and consent is the one with a legal claim on going
    /// first — it governs whether the ads that are already shipping may be
    /// personalised.
    func evaluate() async {
        let started = Date()

        while !Task.isCancelled {
            let decision = OnboardingGate.decide(
                OnboardingGate.Inputs(hasCompletedOnboarding: OnboardingState.hasCompleted,
                                      watchlistCount: WatchlistManager.watchlist.count,
                                      isCloudAvailable: CloudSync.isAvailable,
                                      didMergeWatchlist: didMergeWatchlist,
                                      waited: Date().timeIntervalSince(started)))

            switch decision {
            case .skip:
                // Their data is here, or they have done this before. Mark it
                // done so a later sync landing an empty watchlist can never
                // reopen the question.
                isRestoring = false
                OnboardingState.markCompleted()
                return

            case .show:
                isRestoring = false
                isPresented = true
                return

            case .wait:
                isRestoring = true
                try? await Task.sleep(for: Self.pollInterval)
            }
        }

        isRestoring = false
    }

    /// The flow ended — by finishing or by skipping every step, which are
    /// the same thing as far as being asked again goes.
    func finish() {
        OnboardingState.markCompleted()
        isPresented = false
    }
}
