//
//  WatchedManager.swift
//  Watchnow
//
//  Singleton ObservableObject store for the "already watched" list.
//
//  Was previously an `enum` with a `@UserDefault` static — that worked for
//  reads/writes but didn't notify SwiftUI when the list changed, so views
//  that show watched state (the green badge on BottomCard / TopCard, the
//  filled eye in PrimaryActionRow) wouldn't refresh when the user toggled
//  watched from a different screen and navigated back.
//
//  Now: a `@MainActor` `ObservableObject` with `@Published` storage.
//  Any view that wants to react to changes does so by observing
//  `WatchedManager.shared` via `@ObservedObject`, and the rest of the
//  static-style API is preserved through `shared.method(...)` calls at the
//  call sites.
//

import Foundation

@MainActor
final class WatchedManager: ObservableObject {

    /// Shared instance. The "already watched" list is global to the app —
    /// there is only ever one truth, so a singleton is the simplest model.
    static let shared = WatchedManager()

    /// Source of truth. Persisted to `UserDefaults` on every mutation.
    /// `private(set)` so consumers can read but only this class can mutate.
    @Published private(set) var watchedlist: [Result]

    private static let storageKey = "watchedlist"

    private init() {
        // Decode the existing UserDefaults blob on launch. A failure here
        // (corrupt data, schema change) silently falls back to an empty
        // list — losing the watched history is preferable to crashing.
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([Result].self, from: data) {
            self.watchedlist = decoded
        } else {
            self.watchedlist = []
        }
    }

    // MARK: - Mutations

    func addToWatched(result: Result) {
        guard !watchedlist.contains(result) else { return }
        watchedlist.append(result)
        persist()
    }

    func removeFromWatched(result: Result) {
        if let index = watchedlist.firstIndex(of: result) {
            watchedlist.remove(at: index)
            persist()
        }
    }

    // MARK: - Queries

    func existsInWatched(result: Result) -> Bool {
        watchedlist.contains(result)
    }

    // MARK: - Persistence

    private func persist() {
        guard let encoded = try? JSONEncoder().encode(watchedlist) else { return }
        UserDefaults.standard.set(encoded, forKey: Self.storageKey)
    }
}
