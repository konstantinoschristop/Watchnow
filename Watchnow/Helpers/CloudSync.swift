//
//  CloudSync.swift
//  Watchnow
//
//  Mirrors the watchlist, folders and Movie Night service prefs to iCloud's
//  key-value store so they roam across the user's devices (and survive an
//  app delete + reinstall). Local `UserDefaults` stays the synchronous
//  working copy — offline-safe and instant to read; the cloud store is a
//  mirror that's pushed when the app writes a synced key, and pulled when
//  iCloud reports a remote change.
//
//  Requires the iCloud "Key-value storage" capability in the target's
//  Signing & Capabilities (entitlement `com.apple.developer.ubiquity-
//  kvstore-identifier`). Without it the `NSUbiquitousKeyValueStore` calls
//  are harmless no-ops, so the app keeps working fully local-only.
//
//  Not synced (intentionally): reminders (device-local notifications),
//  search history, Movie Coach's generated answers and its recommendation
//  graph (both derived caches, cheaper to rebuild than to ship around), and
//  any per-device UI state.
//

import Foundation

enum CloudSync {

    /// Posted (on the main queue) after remote changes have been merged into
    /// `UserDefaults`, so the in-memory stores can reload and republish.
    /// `userInfo[changedKeysKey]` carries the affected keys as `[String]`.
    static let didMergeRemoteChanges = Notification.Name("CloudSyncDidMergeRemoteChanges")
    static let changedKeysKey = "keys"

    /// The `UserDefaults` keys that mirror to iCloud.
    static let syncedKeys: Set<String> = [
        "watchlist",                    // WatchlistManager — saved titles
        "watchlistAddedDates",          // WatchlistManager — when each was saved
        "watchlist_folders",            // FolderManager — folder definitions
        "watchlist_folder_membership",  // FolderManager — title → folder map
        "movieNightProviderIDs",        // StreamingPreferences

        // TasteProfile — what the user actually likes. This is real user
        // preference, not derived state, so it should follow them between
        // devices exactly like the watchlist does.
        "tasteLikedIDs",                // titles they said "I like this" to
        "tasteLikedGenres",             // genre weights from those likes
        "tasteLikedLanguages",          // languages they gravitate to
        "tastePassedGenres"             // Movie Night passes (implicit dislikes)
    ]

    /// Whether the device is signed into iCloud, so the key-value store can
    /// actually sync. The UI uses this to decide whether to show the
    /// "Synced via iCloud" caption (so it never claims sync when there's none).
    static var isAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    /// One-time guard. Only ever touched on the main thread at launch.
    nonisolated(unsafe) private static var started = false

    /// Begin observing iCloud and reconcile cloud ↔ local. Call once at launch.
    static func start() {
        guard !started else { return }
        started = true

        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { note in
            let keys = (note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String])
                ?? Array(syncedKeys)
            pull(keys: keys)
        }

        NSUbiquitousKeyValueStore.default.synchronize()
        reconcileAtLaunch()
    }

    /// Push `key`'s current local value up to iCloud. The synced stores call
    /// this right after they persist to `UserDefaults`. No-op for keys that
    /// aren't in `syncedKeys`, so it's safe to call from a generic write path.
    static func pushIfSynced(_ key: String) {
        guard syncedKeys.contains(key) else { return }
        let cloud = NSUbiquitousKeyValueStore.default
        if let data = UserDefaults.standard.data(forKey: key) {
            cloud.set(data, forKey: key)
        } else {
            cloud.removeObject(forKey: key)
        }
        if cloud.synchronize() && isAvailable { noteActivity() }
    }

    // MARK: - Private

    /// On launch: seed iCloud from this device for keys it doesn't have yet,
    /// and pull down keys iCloud already holds (from another device). iCloud
    /// resolves true conflicts itself (last writer wins), which is the right
    /// model for a personal watchlist.
    private static func reconcileAtLaunch() {
        let cloud = NSUbiquitousKeyValueStore.default
        let local = UserDefaults.standard
        var pulled: [String] = []

        for key in syncedKeys {
            let cloudData = cloud.data(forKey: key)
            let localData = local.data(forKey: key)
            if let cloudData {
                if cloudData != localData {
                    local.set(cloudData, forKey: key)
                    pulled.append(key)
                }
            } else if let localData {
                cloud.set(localData, forKey: key)
            }
        }

        if !pulled.isEmpty {
            cloud.synchronize()
            postMerge(pulled)
        }
        // When iCloud is available the store is in sync after reconciling
        // (whether we pulled, seeded, or it already matched).
        if isAvailable { noteActivity() }
    }

    /// Copy the given keys' cloud values down into `UserDefaults`.
    private static func pull(keys: [String]) {
        let cloud = NSUbiquitousKeyValueStore.default
        let local = UserDefaults.standard
        var changed: [String] = []

        for key in keys where syncedKeys.contains(key) {
            if let data = cloud.data(forKey: key) {
                local.set(data, forKey: key)
            } else {
                local.removeObject(forKey: key)
            }
            changed.append(key)
        }

        if !changed.isEmpty {
            noteActivity()
            postMerge(changed)
        }
    }

    private static func postMerge(_ keys: [String]) {
        NotificationCenter.default.post(
            name: didMergeRemoteChanges,
            object: nil,
            userInfo: [changedKeysKey: keys]
        )
    }

    private static func noteActivity() {
        Task { @MainActor in SyncStatus.shared.noteActivity() }
    }
}

// MARK: - SyncStatus

/// Observable "last synced" state for the iCloud mirror, so the UI can show a
/// quiet "Synced via iCloud" caption. `lastSyncedAt` is stamped on each
/// successful push/pull; `isAvailable` reflects whether the user is signed
/// into iCloud at all.
@MainActor
final class SyncStatus: ObservableObject {

    static let shared = SyncStatus()

    /// Most recent successful sync activity. `nil` until the first one, so the
    /// caption can stay hidden on a brand-new install with nothing to say.
    @Published private(set) var lastSyncedAt: Date?

    var isAvailable: Bool { CloudSync.isAvailable }

    private init() {}

    func noteActivity() {
        lastSyncedAt = Date()
    }
}
