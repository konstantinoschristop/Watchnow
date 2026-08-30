//
//  KeywordEnricher.swift
//  Watchnow
//
//  Background fill of `KeywordStore` for the user's watchlist, so Movie
//  Coach can reason about themes rather than genres alone.
//
//  Principles:
//   - Never blocks anything. Runs a couple of seconds after launch, in
//     small batches, and Coach simply uses whatever is cached whenever it
//     is asked — personalisation sharpens as the cache fills.
//   - The cache *is* the progress state. Every launch scans the watchlist,
//     fetches only what's missing or expired, and stops; a fully enriched
//     watchlist costs zero requests, and a giant one just continues where
//     the previous launch left off (evictions and failures self-heal).
//   - Failures are silent. A title that fails stays uncached and is retried
//     on the next pass, and stale entries survive a failed refresh — Movie
//     Coach must never notice any of this going wrong.
//

import Foundation

@MainActor
enum KeywordEnricher {

    /// Keyword requests in flight at once. Small on purpose: a 100-title
    /// backlog clears in well under a minute without hammering TMDB
    /// alongside the app's own launch traffic.
    private static let batchSize = 3

    /// Breather between batches.
    private static let batchPause: Duration = .milliseconds(250)

    /// Head start given to the home screens' own requests.
    private static let launchDelay: Duration = .seconds(2)

    private static var isRunning = false

    // MARK: - Watchlist pass

    /// Fetch keywords for every watchlist title that has no fresh cache
    /// entry, most recently saved first (the titles Coach is most likely to
    /// be asked about next). Call once per launch, after the UI is up.
    static func enrichWatchlist(using service: ServiceInvocation = ServiceInvocation()) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        try? await Task.sleep(for: launchDelay)
        guard !Task.isCancelled else { return }

        let fresh = KeywordStore.freshKeys()
        let pending = WatchlistManager.watchlist.enumerated()
            .filter { _, item in
                guard let id = item.id else { return false }
                return !fresh.contains(KeywordStore.key(type: item.inferredScreenType, id: id))
            }
            .sorted { lhs, rhs in
                // Recorded save dates first, newest on top. Items from
                // before dates were recorded keep their array order, where
                // later means more recently added.
                let lhsDate = lhs.element.id.flatMap(WatchlistManager.addedDate(forID:))
                let rhsDate = rhs.element.id.flatMap(WatchlistManager.addedDate(forID:))
                switch (lhsDate, rhsDate) {
                case let (l?, r?):  return l > r
                case (.some, nil):  return true
                case (nil, .some):  return false
                case (nil, nil):    return lhs.offset > rhs.offset
                }
            }
            .map(\.element)

        guard !pending.isEmpty else { return }

        var index = 0
        while index < pending.count, !Task.isCancelled {
            let batch = pending[index ..< min(index + batchSize, pending.count)]
            await fetch(batch: Array(batch), using: service)
            index += batchSize
            try? await Task.sleep(for: batchPause)
        }
    }

    /// One batch, fetched concurrently. Successful responses (including
    /// legitimately empty keyword lists) are cached; failures are dropped so
    /// any older entry survives and the title is retried next pass.
    private static func fetch(batch: [Result], using service: ServiceInvocation) async {
        await withTaskGroup(of: (Int, ScreenTypes, [String]?).self) { group in
            for item in batch {
                guard let id = item.id else { continue }
                let type = item.inferredScreenType
                group.addTask {
                    let response = try? await service.fetchKeywords(screenType: type, id: String(id))
                    return (id, type, response.map { $0.all.compactMap(\.name) })
                }
            }
            for await (id, type, names) in group {
                guard let names else { continue }
                KeywordStore.store(names, type: type, id: id)
            }
        }
    }

    // MARK: - Single title

    /// Enrich one just-saved title. Fire-and-forget — the watchlist add has
    /// already happened by the time this runs, and a failure just leaves the
    /// title for the next launch pass.
    static func enrich(_ item: Result, using service: ServiceInvocation = ServiceInvocation()) async {
        guard let id = item.id else { return }
        let type = item.inferredScreenType
        guard !KeywordStore.isFresh(type: type, id: id) else { return }
        guard let response = try? await service.fetchKeywords(screenType: type, id: String(id)) else { return }
        KeywordStore.store(response.all.compactMap(\.name), type: type, id: id)
    }
}
