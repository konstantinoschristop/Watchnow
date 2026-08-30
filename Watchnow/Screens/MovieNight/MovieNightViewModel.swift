//
//  MovieNightViewModel.swift
//  Watchnow
//
//  Drives the Movie Night flow: fetches a candidate deck from TMDB
//  Discover (blended with watchlist movies), runs the pass-and-play swipe
//  session across N players, and computes the title(s) everyone liked.
//

import Foundation

@MainActor
final class MovieNightViewModel: ObservableObject {

    // MARK: - Published flow state

    @Published var phase: MovieNightPhase = .setup

    /// Streaming-service catalogue backing the setup screen's "Where" row.
    @Published var availableProviders: [WatchProvider] = []

    /// The shuffled deck every player swipes through.
    @Published private(set) var deck: [Result] = []

    /// Index of the card the current player is looking at.
    @Published private(set) var cardIndex: Int = 0

    /// 1-based index of the player currently swiping.
    @Published private(set) var currentPlayer: Int = 1

    /// True between players: player N has reached the end of the deck and
    /// we're waiting for them to hand the phone to player N+1.
    @Published private(set) var awaitingHandoff = false

    /// Set by the results screen to push a details page.
    @Published var detailTarget: Result?

    // MARK: - Private session state

    private var criteria = MovieNightCriteria()
    /// What the last session was started with, if any. The setup screen's
    /// selections live in its own @State, which SwiftUI recreates whenever
    /// the flow returns to setup ("Start over", the empty screen) — this is
    /// what lets it restore the user's picks instead of showing cleared
    /// chips.
    private(set) var lastCriteria: MovieNightCriteria?
    /// Per-player sets of liked result IDs. `likes[i]` belongs to player i+1.
    private var likes: [Set<Int>] = []
    /// Discover page last fetched, so "Deal again" pulls fresh titles.
    private var lastPage = 0
    /// Total Discover pages for the current criteria (0 = not known yet).
    /// A narrow filter combo often has a single page — without this,
    /// "Deal again" walked past the end of the filtered results and came
    /// back with nothing, silently dropping the user's filters.
    private var totalPages = 0
    /// Every card dealt under the current criteria, so wrapped-around pages
    /// and the watchlist blend don't redeal the same titles until the
    /// filtered pool is genuinely exhausted.
    private var dealtIDs: Set<Int> = []

    private let service = ServiceInvocation()
    private var region: String { Locale.current.region?.identifier ?? "US" }

    /// Exposed read-only so the swipe/results screens can branch on the
    /// number of players (e.g. solo skips the "Pass the phone" handoff).
    var playerCount: Int { criteria.playerCount }

    // MARK: - Setup support

    /// Loads the region's streaming catalogue for the "Where" chips. Soft
    /// fails — an empty row just means the user can't filter by service.
    /// Capped at the 5 most prominent services (TMDB's `display_priority`
    /// surfaces the household names — Netflix, Prime, Disney+ … — first) to
    /// keep the row to the platforms people actually recognise.
    func loadProvidersIfNeeded() async {
        guard availableProviders.isEmpty else { return }
        if let response = try? await service.fetchProviders(screenType: .movie, region: region) {
            let rank = Self.subscriptionRank
            availableProviders = (response.results ?? [])
                .filter { rank[$0.provider_id] != nil }
                .sorted { (rank[$0.provider_id] ?? .max) < (rank[$1.provider_id] ?? .max) }
                .prefix(5)
                .map { $0 }
        }
    }

    /// Major subscription services in rough global-recognition order. Movie
    /// Night shows the first few of these the user's region actually carries
    /// — subscriptions only, never rent/buy storefronts (Apple TV Store,
    /// Google Play), free/ad tiers, or transactional platforms.
    ///
    /// We curate both the set *and* the order by stable provider ID because
    /// TMDB's provider list doesn't tag monetization and its `display_
    /// priority` is erratic across regions (it ranks Sun Nxt above Hulu in
    /// the US). Ordering here instead of by `display_priority` keeps the row
    /// to household names. id 350 ("Apple TV") is the Apple TV+ subscription;
    /// the rent/buy "Apple TV Store" (id 2) is intentionally absent. Regional
    /// services sit at the end so they only surface where the majors don't.
    private static let subscriptionProviders: [Int] = [
        8,         // Netflix
        9, 119,    // Amazon Prime Video (+ regional id)
        337,       // Disney+
        350,       // Apple TV (Apple TV+)
        1899, 384, // Max / HBO Max
        15,        // Hulu
        531,       // Paramount+
        386, 387,  // Peacock
        283,       // Crunchyroll
        37,        // Showtime
        43,        // Starz
        520,       // Discovery+
        526,       // AMC+
        11,        // MUBI
        151,       // BritBox
        39,        // NOW
        29,        // Sky Go
        122,       // Disney+ Hotstar (regional)
        309,       // Sun Nxt (regional)
        232,       // ZEE5 (regional)
        220        // JioCinema (regional)
    ]

    /// provider_id → its index in `subscriptionProviders` (lower = shown first).
    private static let subscriptionRank: [Int: Int] =
        Dictionary(subscriptionProviders.enumerated().map { ($1, $0) },
                   uniquingKeysWith: { first, _ in first })

    // MARK: - Session lifecycle

    /// Persist the chosen services and build the first deck.
    func start(with criteria: MovieNightCriteria) {
        self.criteria = criteria
        self.lastCriteria = criteria
        StreamingPreferences.save(criteria.providerIDs)
        lastPage = 0
        totalPages = 0
        dealtIDs = []
        Task { await dealDeck() }
    }

    /// Re-roll a fresh deck with the same criteria (next Discover page) and
    /// restart the swipe session from player 1.
    func dealAgain() {
        Task { await dealDeck() }
    }

    /// Back to the setup screen, keeping the previous selections.
    func backToSetup() {
        phase = .setup
    }

    // MARK: - Swiping

    /// Record the current player's verdict on the current card and advance.
    func swipe(liked: Bool) {
        guard cardIndex < deck.count else { return }
        let card = deck[cardIndex]
        if liked, let id = card.id {
            likes[currentPlayer - 1].insert(id)
        }
        // A pass is the one explicit "no" the app ever sees. Record it as a
        // light negative for Movie Coach — but only on player 1's turn, since
        // in pass-and-play the later turns belong to other people.
        if !liked, currentPlayer == 1 {
            TasteProfile.recordPass(card)
        }
        cardIndex += 1
        if cardIndex >= deck.count {
            finishPlayerTurn()
        }
    }

    /// The next player picks up the phone and starts the deck over.
    func beginNextPlayer() {
        currentPlayer += 1
        cardIndex = 0
        awaitingHandoff = false
    }

    /// 0…1 progress of the current player through the deck.
    var progress: Double {
        guard !deck.isEmpty else { return 0 }
        return Double(cardIndex) / Double(deck.count)
    }

    private func finishPlayerTurn() {
        if currentPlayer < criteria.playerCount {
            awaitingHandoff = true
        } else {
            phase = .results
        }
    }

    // MARK: - Results

    /// Titles every player liked, richest-first (deck order ≈ popularity).
    var matches: [Result] {
        guard let first = likes.first else { return [] }
        let common = likes.dropFirst().reduce(first) { $0.intersection($1) }
        return deck.filter { common.contains($0.id ?? -1) }
    }

    var topMatch: Result? { matches.first }

    /// When there's no unanimous pick, the titles liked by the most players
    /// (ties broken by deck order). Used for the "closest" fallback.
    var closestPicks: [Result] {
        deck.compactMap { result -> (Result, Int)? in
            guard let id = result.id else { return nil }
            let votes = likes.filter { $0.contains(id) }.count
            return votes > 0 ? (result, votes) : nil
        }
        .sorted { $0.1 > $1.1 }
        .prefix(6)
        .map(\.0)
    }

    // MARK: - Deck building

    private func dealDeck() async {
        phase = .loading
        deck = []
        cardIndex = 0
        currentPlayer = 1
        awaitingHandoff = false
        likes = Array(repeating: [], count: max(criteria.playerCount, 1))

        // Advance through Discover's pages, wrapping back to page 1 once the
        // filtered result set runs out. TMDB returns an empty array for a
        // page past the end, and a narrow combo (mood + runtime + service +
        // the vote floor) frequently has exactly one page — so without the
        // wrap, "Deal again" dealt a deck that ignored the filters (whatever
        // watchlist titles were left) or dropped to the empty screen.
        lastPage = (totalPages > 0 && lastPage >= totalPages) ? 1 : lastPage + 1

        var pool: [Result] = []
        var fetchFailed = false
        if let response = try? await service.discover(
            genreIDs: criteria.genreIDs,
            runtimeLTE: criteria.length.runtimeLTE,
            providerIDs: Array(criteria.providerIDs),
            region: region,
            page: lastPage
        ) {
            pool = response.results
            totalPages = response.total_pages ?? 1
        } else {
            // Retry the same page on the next deal instead of skipping it.
            fetchFailed = true
            lastPage -= 1
        }

        // Blend in watchlist movies that fit the chosen moods so the user's
        // own saved titles get a chance to win the night.
        let merged = dedupedMovies(watchlistCandidates() + pool)

        guard !merged.isEmpty else {
            phase = fetchFailed ? .error : .empty
            return
        }

        // Cap the deck to a short, decisive round (not a chore), dealing
        // titles this session hasn't shown yet first and topping up with
        // repeats only once the filtered pool runs low — never a thin deck.
        // Both halves shuffled so repeat deals see a fresh order.
        let fresh = merged.filter { !dealtIDs.contains($0.id ?? -1) }.shuffled()
        let repeats = merged.filter { dealtIDs.contains($0.id ?? -1) }.shuffled()
        deck = Array((fresh + repeats).prefix(8))

        // This deal used up the last unseen titles — start the rotation over
        // so the next one cycles the pool again instead of repeating this
        // exact deck.
        if fresh.count <= 8 { dealtIDs = [] }
        dealtIDs.formUnion(deck.compactMap(\.id))
        phase = .swiping
    }

    /// Drops duplicates (by id) and posterless entries, and stamps every
    /// survivor as a movie so downstream detail navigation knows its type.
    private func dedupedMovies(_ results: [Result]) -> [Result] {
        var seen = Set<Int>()
        return results.compactMap { result in
            guard let id = result.id, result.poster_path != nil,
                  seen.insert(id).inserted else { return nil }
            var typed = result
            typed.media_type = ScreenTypes.movie.rawValue
            return typed
        }
    }

    /// Movies from the watchlist whose genres intersect the selected moods
    /// (or all of them when no mood is picked).
    private func watchlistCandidates() -> [Result] {
        let wanted = Set(criteria.genreIDs)
        return WatchlistManager.watchlist.filter { result in
            // TV titles carry `name`; movies carry `title`. Prefer the
            // explicit media_type when present, fall back to that heuristic.
            let isMovie = result.media_type == ScreenTypes.movie.rawValue
                || (result.media_type == nil && result.title != nil)
            guard isMovie else { return false }
            guard !wanted.isEmpty else { return true }
            return !Set(result.genre_ids ?? []).isDisjoint(with: wanted)
        }
    }
}
