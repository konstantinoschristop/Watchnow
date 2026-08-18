//
//  TasteProfile.swift
//  Watchnow
//
//  What WatchNow actually knows about the user's taste, as opposed to what
//  they merely saved for later.
//
//  Three sources, in descending order of confidence:
//
//   1. "More like this" — an explicit, deliberate tap. Strongest signal we
//      have. One positive button rather than a like/dislike pair, because
//      people happily tell you what they love and rarely bother filing
//      complaints.
//   2. Movie Night passes — implicit negatives the app was already
//      collecting and throwing away. Weighted lightly: a pass often means
//      "not tonight" rather than "never".
//   3. The reverse-recommendation graph — for the titles the user likes, TMDB
//      already knows what pairs well with them. Building the union of those
//      recommendations turns TMDB's own collaborative filtering into a taste
//      signal, which beats genre matching by a wide margin.
//
//  All device-local; none of it is synced.
//

import Foundation

@MainActor
enum TasteProfile {

    // MARK: - Stored signals

    /// TMDB ids the user explicitly asked for more of.
    @UserDefault("tasteLikedIDs", defaultValue: [])
    private(set) static var likedIDs: [Int]

    /// Normalised genre → weight, from explicit likes.
    @UserDefault("tasteLikedGenres", defaultValue: [:])
    private(set) static var likedGenres: [String: Int]

    /// Original-language → weight, from explicit likes.
    @UserDefault("tasteLikedLanguages", defaultValue: [:])
    private(set) static var likedLanguages: [String: Int]

    /// Normalised genre → weight, from Movie Night passes.
    @UserDefault("tastePassedGenres", defaultValue: [:])
    private(set) static var passedGenres: [String: Int]

    /// TMDB id (as String) → how many liked/saved titles recommend it.
    @UserDefault("tasteRecommendedIDs", defaultValue: [:])
    private(set) static var recommendedIDs: [String: Int]

    @UserDefault("tasteGraphBuiltAt", defaultValue: 0)
    private static var graphBuiltAt: Double

    // MARK: - Explicit likes

    static func isLiked(_ id: Int?) -> Bool {
        guard let id else { return false }
        return likedIDs.contains(id)
    }

    /// Record an explicit "I like this". Takes the pieces rather than a
    /// `Result` so callers never have to fabricate one — a details screen
    /// opened from a deeplink has genre ids on `details`, not on `result`.
    static func like(id: Int, genreIDs: [Int], language: String?) {
        guard !likedIDs.contains(id) else { return }
        likedIDs.append(id)

        for name in normalized(genreIDs) {
            likedGenres[name, default: 0] += 3          // explicit ≫ a passive save
        }
        if let language {
            likedLanguages[language, default: 0] += 1
        }
        // The graph is now out of date — this title's recommendations matter.
        graphBuiltAt = 0
    }

    static func unlike(id: Int, genreIDs: [Int], language: String?) {
        likedIDs.removeAll { $0 == id }

        for name in normalized(genreIDs) {
            if let current = likedGenres[name] {
                let next = current - 3
                if next > 0 { likedGenres[name] = next } else { likedGenres[name] = nil }
            }
        }
        if let language, let current = likedLanguages[language] {
            let next = current - 1
            if next > 0 { likedLanguages[language] = next } else { likedLanguages[language] = nil }
        }
        graphBuiltAt = 0
    }

    // MARK: - Implicit negatives

    /// A Movie Night swipe-left. Only the device owner's turn should call
    /// this — in pass-and-play the other players aren't the user.
    static func recordPass(_ result: Result) {
        for name in genreNames(of: result) {
            passedGenres[name, default: 0] += 1
        }
    }

    // MARK: - Reverse-recommendation graph

    static func recommendationHits(for id: Int?) -> Int {
        guard let id else { return 0 }
        return recommendedIDs[String(id)] ?? 0
    }

    private static let graphMaxAge: TimeInterval = 7 * 24 * 3600
    private static var graphIsStale: Bool {
        Date().timeIntervalSince1970 - graphBuiltAt > graphMaxAge
    }

    /// Ask TMDB what pairs with the titles this user likes, and keep the
    /// union. Runs at most weekly, capped to a handful of seed titles, and
    /// fails silently — it's an enhancement, never a dependency.
    static func rebuildGraphIfNeeded(using service: ServiceInvocation) async {
        guard graphIsStale else { return }

        // Seed from explicit likes first, then fall back to saved titles.
        let watchlist = WatchlistManager.watchlist
        let liked = watchlist.filter { isLiked($0.id) }
        let seeds = Array((liked + watchlist).uniquedByID().prefix(10))
        guard !seeds.isEmpty else { return }

        var tally: [String: Int] = [:]
        await withTaskGroup(of: [Int].self) { group in
            for seed in seeds {
                guard let id = seed.id else { continue }
                let type: ScreenTypes = (seed.media_type == "tv") ? .tv : .movie
                // Explicit likes count double when they recommend something.
                let weight = isLiked(id) ? 2 : 1
                group.addTask {
                    let response = try? await service.fetchRecommendations(screenType: type, id: id)
                    let ids = (response?.results ?? []).compactMap(\.id)
                    return Array(repeating: ids, count: weight).flatMap { $0 }
                }
            }
            for await ids in group {
                for id in ids { tally[String(id), default: 0] += 1 }
            }
        }

        guard !tally.isEmpty else { return }
        // Keep only titles recommended by more than one seed — a single
        // recommendation is noise, agreement is signal.
        recommendedIDs = tally.filter { $0.value >= 2 }
        graphBuiltAt = Date().timeIntervalSince1970
    }

    // MARK: - Helpers

    private static func genreNames(of result: Result) -> [String] {
        normalized(result.genre_ids ?? [])
    }

    private static func normalized(_ genreIDs: [Int]) -> [String] {
        genreIDs.compactMap { tmdbGenreNames[$0] }
            .map(MovieCoachContext.normalizedGenre)
    }
}

private extension Array where Element == Result {
    /// De-dupes by TMDB id, preserving order.
    func uniquedByID() -> [Result] {
        var seen = Set<Int>()
        return filter { item in
            guard let id = item.id else { return false }
            return seen.insert(id).inserted
        }
    }
}
