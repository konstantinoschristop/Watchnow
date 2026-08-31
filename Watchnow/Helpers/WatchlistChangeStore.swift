//
//  WatchlistChangeStore.swift
//  Watchnow
//
//  Persistence for What's New: the per-title snapshots the classifier
//  diffs against, the detected-but-unseen changes, the seen-id ledger, and
//  the timestamps that gate when the briefing may appear.
//
//  All the "should the sheet show?" policy lives here — views and view
//  models ask, they never decide. Device-local by design: snapshots embed
//  region-specific provider data and seen-state is per-device attention,
//  so none of it belongs in `CloudSync.syncedKeys`.
//

import Foundation

@MainActor
enum WatchlistChangeStore {

    // MARK: - Tunables

    /// How long the user must be gone before a return counts as "away".
    static var awayThreshold: TimeInterval = 24 * 3600

    /// Detected changes older than this stop being news and are dropped.
    static let maxChangeAge: TimeInterval = 30 * 24 * 3600

    private static let maxSeenIDs = 300

    // MARK: - Storage

    @UserDefault("whatsNewSnapshots", defaultValue: [:])
    private static var snapshots: [String: WatchlistSnapshot]

    @UserDefault("whatsNewPending", defaultValue: [])
    private static var pending: [WatchlistChange]

    @UserDefault("whatsNewSeenIDs", defaultValue: [])
    private static var seenIDs: [String]

    @UserDefault("whatsNewLastLaunch", defaultValue: 0)
    private static var lastMeaningfulLaunchEpoch: Double

    @UserDefault("whatsNewLastSync", defaultValue: 0)
    private static var lastSyncEpoch: Double

    // MARK: - Snapshots

    static func snapshot(mediaType: String, mediaID: Int) -> WatchlistSnapshot? {
        snapshots[WatchlistSnapshot.key(mediaType: mediaType, mediaID: mediaID)]
    }

    static func save(_ snapshot: WatchlistSnapshot) {
        snapshots[snapshot.key] = snapshot
    }

    /// Drop snapshots for titles no longer in the watchlist, so removed
    /// titles stop being checked (and never resurface as changes).
    static func pruneSnapshots(keeping keys: Set<String>) {
        snapshots = snapshots.filter { keys.contains($0.key) }
    }

    static var snapshotCount: Int { snapshots.count }

    // MARK: - Changes

    /// Add freshly detected changes. Anything already seen, already pending,
    /// or stale is ignored, so re-detection can never re-surface old news.
    /// Returns how many were genuinely new.
    @discardableResult
    static func add(_ changes: [WatchlistChange], now: Date = Date()) -> Int {
        var store = pending.filter { now.timeIntervalSince1970 - $0.occurredAt < maxChangeAge }
        let seen = Set(seenIDs)
        let existing = Set(store.map(\.id))

        var added = 0
        for change in changes {
            guard !seen.contains(change.id), !existing.contains(change.id),
                  now.timeIntervalSince1970 - change.occurredAt < maxChangeAge
            else { continue }
            store.append(change)
            added += 1
        }
        pending = store
        return added
    }

    /// Everything detected and not yet shown, unranked — presentation order
    /// is `ChangeClassifier.ranked`'s job.
    static func unseenChanges(now: Date = Date()) -> [WatchlistChange] {
        pending.filter { now.timeIntervalSince1970 - $0.occurredAt < maxChangeAge }
    }

    static func markSeen(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        let marked = Set(ids)
        pending = pending.filter { !marked.contains($0.id) }
        seenIDs = Array((seenIDs + ids).suffix(maxSeenIDs))
    }

    /// The briefing was shown (or dismissed) — its whole batch is spent,
    /// including overflow beyond the visible five. Nothing should trickle
    /// out again on the next launch.
    static func markAllSeen() {
        markSeen(pending.map(\.id))
    }

    static var seenCount: Int { seenIDs.count }

    // MARK: - Presentation gate

    /// True when the user is returning after a real absence. A first-ever
    /// launch (nothing recorded) is not "away" — that's baseline territory,
    /// never briefing territory.
    static func wasAway(now: Date = Date()) -> Bool {
        guard lastMeaningfulLaunchEpoch > 0 else { return false }
        return now.timeIntervalSince1970 - lastMeaningfulLaunchEpoch >= awayThreshold
    }

    static func recordMeaningfulLaunch(now: Date = Date()) {
        lastMeaningfulLaunchEpoch = now.timeIntervalSince1970
    }

    // MARK: - Sync bookkeeping

    static var lastSyncAt: Double { lastSyncEpoch }

    static func recordSync(now: Date = Date()) {
        lastSyncEpoch = now.timeIntervalSince1970
    }

    // MARK: - Reset

    /// Wipe everything — debug tooling and tests only.
    static func reset() {
        snapshots = [:]
        pending = []
        seenIDs = []
        lastMeaningfulLaunchEpoch = 0
        lastSyncEpoch = 0
    }

    #if DEBUG
    /// Debug time travel: pretend the last open was `interval` ago.
    static func debugShiftLastLaunch(by interval: TimeInterval) {
        lastMeaningfulLaunchEpoch = Date().timeIntervalSince1970 - interval
    }
    #endif
}
