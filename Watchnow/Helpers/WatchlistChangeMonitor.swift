//
//  WatchlistChangeMonitor.swift
//  Watchnow
//
//  Background sync for What's New: walks the watchlist, asks TMDB what
//  moved, hands the diffs to `ChangeClassifier`, and files the results in
//  `WatchlistChangeStore`.
//
//  Cost discipline, per title per sync:
//   - 1× `/changes` (pre-filter) + 1× watch/providers (the one domain
//     `/changes` doesn't cover) — always.
//   - details / videos only when the pre-filter (or a date we were already
//     waiting on, like a scheduled episode airing) says they're worth it.
//  Titles without a snapshot get the full baseline fetch instead, which by
//  definition produces zero changes — first install shows nothing.
//
//  Runs at most every `minSyncInterval`, in small batches, a couple of
//  seconds after launch. Failures are silent: a title that errors keeps its
//  old snapshot untouched and is simply retried next sync.
//

import Foundation

@MainActor
enum WatchlistChangeMonitor {

    /// Minimum gap between syncs. Watchlist titles don't change hourly.
    static var minSyncInterval: TimeInterval = 12 * 3600

    /// TMDB caps a `/changes` window at 14 days; stay just inside it.
    /// (`nonisolated`: read from the off-main fetch path.)
    private nonisolated static let changesWindow: TimeInterval = 13 * 24 * 3600

    private static let batchSize = 3
    private static let batchPause: Duration = .milliseconds(250)
    private static let launchDelay: Duration = .seconds(2)

    /// Used when the user has actually been away. There is no background
    /// refresh in this app, so on that launch this sync *is* the feature —
    /// nothing was pre-computed and the briefing cannot exist until it
    /// finishes. It skips the courtesy delay and runs wider batches,
    /// deliberately competing with the home tabs' own requests.
    /// Concurrency still equals the batch size (each title's requests run
    /// in sequence inside `fetchState`), so this stays well inside TMDB's
    /// tolerance.
    private static let urgentBatchSize = 6
    private static let urgentBatchPause: Duration = .milliseconds(80)

    private static var isRunning = false

    // MARK: - Sync

    /// Run a sync when one is due. Returns whether any new change was
    /// stored — the caller uses that to re-evaluate the briefing.
    @discardableResult
    static func syncIfNeeded(using service: ServiceInvocation = ServiceInvocation(),
                             force: Bool = false,
                             urgent: Bool = false) async -> Bool {
        let now = Date()
        guard !isRunning else { return false }
        guard force || now.timeIntervalSince1970 - WatchlistChangeStore.lastSyncAt >= minSyncInterval else {
            return false
        }

        isRunning = true
        defer { isRunning = false }

        // The courtesy delay exists so the home tabs' visible content loads
        // first. It's the wrong trade on a return-from-away launch, where
        // the briefing is the thing the user came back to.
        if !urgent {
            try? await Task.sleep(for: launchDelay)
        }
        guard !Task.isCancelled else { return false }

        let watchlist = WatchlistManager.watchlist.filter { $0.id != nil }
        WatchlistChangeStore.pruneSnapshots(keeping: Set(watchlist.compactMap { item in
            item.id.map { WatchlistSnapshot.key(mediaType: item.inferredScreenType.rawValue, mediaID: $0) }
        }))
        guard !watchlist.isEmpty else {
            WatchlistChangeStore.recordSync(now: now)
            return false
        }

        let region = Locale.current.region?.identifier ?? "US"
        let subscribed = Set(StreamingPreferences.providerIDs)
        var newChangeCount = 0

        let stride = urgent ? urgentBatchSize : batchSize
        let pause = urgent ? urgentBatchPause : batchPause

        var index = 0
        while index < watchlist.count, !Task.isCancelled {
            let batch = watchlist[index ..< min(index + stride, watchlist.count)]

            // Snapshots are read on the main actor, the network runs in
            // child tasks, and the classify/persist step comes back to the
            // main actor — same shape as KeywordEnricher's batches.
            await withTaskGroup(of: (Result, WatchlistSnapshot?, ChangeClassifier.Fresh?).self) { group in
                for item in batch {
                    guard let id = item.id else { continue }
                    let type = item.inferredScreenType
                    let snapshot = WatchlistChangeStore.snapshot(mediaType: type.rawValue, mediaID: id)
                    group.addTask {
                        let fresh = await fetchState(id: id, type: type, snapshot: snapshot,
                                                     region: region, service: service)
                        return (item, snapshot, fresh)
                    }
                }

                for await (item, snapshot, fresh) in group {
                    guard let id = item.id, let fresh else { continue }
                    let type = item.inferredScreenType.rawValue

                    if let snapshot {
                        let hasReminder = ReminderManager.isScheduled(
                            identifier: ReminderManager.titleIdentifier(resultID: id))
                        let changes = ChangeClassifier.changes(from: snapshot,
                                                               fresh: fresh,
                                                               hasReminder: hasReminder,
                                                               subscribedProviderIDs: subscribed)
                        newChangeCount += WatchlistChangeStore.add(changes)
                        WatchlistChangeStore.save(ChangeClassifier.updatedSnapshot(snapshot, fresh: fresh))
                    } else {
                        // First sight of this title — establish the baseline
                        // silently. Requires the full picture; a partial
                        // baseline would misread the gaps as changes later.
                        guard fresh.details != nil, fresh.videos != nil, fresh.providerIDs != nil else { continue }
                        WatchlistChangeStore.save(ChangeClassifier.makeSnapshot(
                            mediaID: id,
                            mediaType: type,
                            title: item.getResultTitle(),
                            posterPath: item.poster_path,
                            backdropPath: item.backdrop_path,
                            fresh: fresh))
                    }
                }
            }

            index += stride
            try? await Task.sleep(for: pause)
        }

        WatchlistChangeStore.recordSync(now: now)
        return newChangeCount > 0
    }

    // MARK: - Per-title fetch

    /// `/changes` keys that justify a details re-fetch.
    /// (`nonisolated`: read from the off-main fetch path.)
    private nonisolated static let relevantMovieKeys: Set<String> = ["videos", "release_dates", "status", "general"]
    private nonisolated static let relevantTVKeys: Set<String> = ["videos", "season", "episode", "status",
                                                                  "first_air_date", "last_air_date", "general"]

    /// All network work for one title. Runs off the main actor; returns nil
    /// when nothing at all could be fetched (title skipped this round).
    private nonisolated static func fetchState(id: Int,
                                               type: ScreenTypes,
                                               snapshot: WatchlistSnapshot?,
                                               region: String,
                                               service: ServiceInvocation) async -> ChangeClassifier.Fresh? {
        var fresh = ChangeClassifier.Fresh()

        // Providers: always fetched — availability changes don't appear in
        // TMDB's /changes feed, diffing is the only way to catch them. On
        // success an absent region / empty flatrate list is a real (empty)
        // state; only a failed request leaves the domain nil and undiffed.
        if let response = try? await service.fetchWatchProviders(screenType: type, id: String(id)) {
            let flatrate = response.results?[region]?.flatrate ?? []
            fresh.providerIDs = flatrate.compactMap(\.providerID)
            fresh.providerNames = Dictionary(uniqueKeysWithValues: flatrate.compactMap { entry in
                guard let pid = entry.providerID, let name = entry.providerName else { return nil }
                return (pid, name)
            })
        }

        guard let snapshot else {
            // Baseline: fetch everything once.
            fresh.details = try? await service.fetchDetails(screenType: type, id: String(id))
            // Only assign on success. A successful response with no videos is
            // a real (empty) state worth recording; a *failed* request must
            // stay nil so it is never diffed and never persisted.
            if let response = try? await service.fetchVideos(screenType: type, id: String(id)) {
                fresh.videos = response.results ?? []
            }
            return (fresh.details == nil && fresh.providerIDs == nil) ? nil : fresh
        }

        // Pre-filter: what did TMDB record since we last looked?
        let windowStart = Date(timeIntervalSince1970: max(
            snapshot.lastCheckedAt,
            Date().timeIntervalSince1970 - changesWindow
        ))
        var changedKeys: Set<String> = []
        if let response = try? await service.fetchChanges(screenType: type,
                                                          id: String(id),
                                                          startDate: dayString(windowStart),
                                                          endDate: dayString(Date())) {
            changedKeys = response.changedKeys
        }

        let relevant = (type == .tv) ? relevantTVKeys : relevantMovieKeys
        var needsDetails = !changedKeys.isDisjoint(with: relevant)

        // Dates we were already waiting on can pass without TMDB recording
        // any edit — a scheduled episode airing, a release day arriving.
        // Those need a details look regardless of the pre-filter.
        if type == .tv, datePassed(snapshot.nextEpisodeAirDate, since: snapshot.lastCheckedAt) {
            needsDetails = true
        }
        if type == .movie, snapshot.status != "Released",
           datePassed(snapshot.releaseDate, since: snapshot.lastCheckedAt) {
            needsDetails = true
        }

        if needsDetails {
            fresh.details = try? await service.fetchDetails(screenType: type, id: String(id))
        }
        if changedKeys.contains("videos"),
           let response = try? await service.fetchVideos(screenType: type, id: String(id)) {
            fresh.videos = response.results ?? []
        }

        let nothingFetched = fresh.details == nil && fresh.videos == nil && fresh.providerIDs == nil
        return nothingFetched ? nil : fresh
    }

    /// Whether a yyyy-MM-dd date has been crossed since the last check.
    private nonisolated static func datePassed(_ raw: String?, since epoch: Double) -> Bool {
        guard let raw, !raw.isEmpty else { return false }
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .iso8601)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: raw) else { return false }
        return date <= Date() && date.timeIntervalSince1970 >= epoch - 24 * 3600
    }

    private nonisolated static func dayString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .iso8601)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    // MARK: - Notifications (future)

    /// Decision layer for local notifications. Nothing calls a scheduler
    /// yet — this exists so a future release can notify without redesigning
    /// anything, and so the policy ("only high-value, never spam") is
    /// already written down and tested.
    static var notificationCooldown: TimeInterval = 24 * 3600

    static func shouldNotify(_ change: WatchlistChange,
                             lastNotifiedAt: Date?,
                             now: Date = Date()) -> Bool {
        if let lastNotifiedAt, now.timeIntervalSince(lastNotifiedAt) < notificationCooldown {
            return false
        }
        // A title the user explicitly asked to hear about always qualifies.
        if change.hasReminder { return true }
        switch change.kind {
        case .streamingAvailability, .newTrailer, .newEpisode, .released:
            return true
        case .releaseDateChanged, .newSeason, .episodeDateChanged:
            return false
        }
    }
}
