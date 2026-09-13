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
//  seconds after launch — and from `BackgroundRefresh` when iOS grants the
//  app time. Failures are silent: a title that errors keeps its old snapshot
//  untouched and is simply retried next sync.
//
//  One run touches at most `maxTitlesPerRun` titles, oldest-checked first,
//  so a long watchlist is walked across several runs rather than in one
//  burst TMDB would be right to throttle.
//
//  Its output is the single source of truth for both surfaces that report
//  change: the "While You Were Away" briefing reads it from
//  `WatchlistChangeStore`, and `AlertPlanner` reads the same store to decide
//  what is worth a notification. There is deliberately no second detector.
//

import Foundation

@MainActor
enum WatchlistChangeMonitor {

    /// Minimum gap between syncs. Watchlist titles don't change hourly.
    static var minSyncInterval: TimeInterval = 12 * 3600

    /// TMDB caps a `/changes` window at 14 days; stay just inside it.
    /// (`nonisolated`: read from the off-main fetch path.)
    private nonisolated static let changesWindow: TimeInterval = 13 * 24 * 3600

    /// Ceiling on how many titles one run will touch.
    ///
    /// Each title costs at least two requests (`/changes` plus
    /// `/watch/providers`) and sometimes four, so an unbounded walk of a
    /// three-hundred-title watchlist is a burst TMDB has every right to
    /// refuse — and a background task has no time for anyway. Titles are
    /// taken oldest-checked first, so what is skipped this run leads the
    /// next one and nothing is starved.
    static let maxTitlesPerRun = 40

    private static let batchSize = 3
    private static let batchPause: Duration = .milliseconds(250)
    private static let launchDelay: Duration = .seconds(2)

    /// Used when the user has actually been away. Background refresh is
    /// opportunistic — iOS may not have granted a run in days — so on that
    /// launch this sync may well be what *creates* the briefing. It skips
    /// the courtesy delay and runs wider batches, deliberately competing
    /// with the home tabs' own requests.
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
        let liveKeys = Set(watchlist.compactMap { item in
            item.id.map { WatchlistSnapshot.key(mediaType: item.inferredScreenType.rawValue, mediaID: $0) }
        })
        WatchlistChangeStore.pruneSnapshots(keeping: liveKeys)
        WatchlistChangeStore.pruneChanges(keeping: liveKeys)
        guard !watchlist.isEmpty else {
            WatchlistChangeStore.recordSync(now: now)
            return false
        }

        // Oldest-checked first, so the cap below skips what was looked at
        // most recently rather than whatever happens to sit at the end of
        // the array. A title with no snapshot yet sorts first: it has never
        // been checked, and until it has a baseline it can produce nothing.
        let due = Array(
            watchlist
                .sorted { lhs, rhs in
                    let lhsChecked = lastCheckedAt(lhs)
                    let rhsChecked = lastCheckedAt(rhs)
                    if lhsChecked != rhsChecked { return lhsChecked < rhsChecked }
                    return (lhs.id ?? 0) < (rhs.id ?? 0)   // deterministic
                }
                .prefix(maxTitlesPerRun)
        )

        let region = Locale.current.region?.identifier ?? "US"
        let subscribed = Set(StreamingPreferences.providerIDs)
        var newChangeCount = 0

        let stride = urgent ? urgentBatchSize : batchSize
        let pause = urgent ? urgentBatchPause : batchPause

        var index = 0
        while index < due.count, !Task.isCancelled {
            let batch = due[index ..< min(index + stride, due.count)]

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

                    // Record where the title streams while we have the answer
                    // in hand. Nothing about What's New needs this — it's the
                    // watchlist's cover badge — but this loop already asks
                    // every saved title for its availability twice a day, and
                    // the alternative is a badge that stays blank until the
                    // user opens each title individually.
                    WatchlistManager.refreshSavedEntry(id: id,
                                                       details: nil,
                                                       providerResults: fresh.providerResults)

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

    /// When this title was last checked, or 0 if it never has been.
    private static func lastCheckedAt(_ item: Result) -> Double {
        guard let id = item.id else { return 0 }
        return WatchlistChangeStore
            .snapshot(mediaType: item.inferredScreenType.rawValue, mediaID: id)?
            .lastCheckedAt ?? 0
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
            fresh.providerResults = response.results?[region]
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
}
