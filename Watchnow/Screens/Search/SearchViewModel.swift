//
//  SearchViewModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 10/7/22.
//

import Foundation

@MainActor
protocol BaseSwipeActionsProtocol: AnyObject {
    var showRemovedAlert: Bool { get set }
    var showAddedAlert: Bool { get set }
    func itemRemoved(result: Result)
}

extension BaseSwipeActionsProtocol {
    func itemRemoved(result: Result) {}
}

@MainActor
class SearchViewModel: ObservableObject, BaseSwipeActionsProtocol {
 
    @Published private var model: SearchModel
    @Published var showRemovedAlert = false
    @Published var showAddedAlert = false
    
    @Published var apiError: Bool = false
    @Published var isSearching: Bool = false
    /// Composed rather than a single fat protocol: search needs the multi
    /// endpoint from `DetailServiceProtocol` and the two feeds from
    /// `SearchDiscoveryServiceProtocol`, and neither has to grow to serve the
    /// other. `ServiceInvocation` happens to satisfy both.
    private let service: any DetailServiceProtocol & SearchDiscoveryServiceProtocol

    init(model: SearchModel,
         service: any DetailServiceProtocol & SearchDiscoveryServiceProtocol = ServiceInvocation()) {

        self.model = model
        self.service = service
        self.model.recentSearches = SearchHistoryManager.recentSearches
    }
    
    func getResults(search: String) async {
        apiError = false
        activeGenre = nil
        // A filter belongs to the result set it was applied to. Carrying
        // "Actors" over from the last query onto a new one meant a search
        // that returned twenty films landed on "0 of 20" and the
        // filtered-away empty state, with nothing on screen explaining why.
        selectedChooser = .all
        isSearching = true
        defer { isSearching = false }
        do {
            searchResponse = try await service.fetchSearchResults(search: search)
            cleanUpResults(results: searchResponse)
            SearchHistoryManager.addSearch(search)
            model.recentSearches = SearchHistoryManager.recentSearches
        } catch {
            apiError = true
        }
    }

    func clearResults() {
        results = nil
        apiError = false
        activeGenre = nil
        selectedChooser = .all
        genrePage = 1
        genreHasMore = false
    }

    /// Returns the tab to its start screen.
    ///
    /// Called when the user navigates away from Search. Without this, a
    /// query and its results outlive the tab switch — so coming back landed
    /// on a stale results list rather than the start screen, and the hero
    /// appeared to have vanished. Nothing is actually lost by clearing: the
    /// query is already in Recent, one tap away.
    ///
    /// Deliberately driven by a tab change rather than `onDisappear`, which
    /// also fires when pushing a details screen — that would wipe the
    /// results the user was about to come back to.
    func endSearchSession() {
        guard !query.isEmpty || results != nil else { return }
        query = ""
        clearResults()
    }

    // MARK: - Genre browse

    /// Fills the results list from a genre tap instead of a typed query.
    ///
    /// Fans out to every media type the genre exists on (see
    /// `SearchModel.Genre.queries`) and interleaves the responses rather
    /// than concatenating them: TMDB returns each side already sorted by
    /// popularity, so appending one list to the other would bury every
    /// series below forty movies. Interleaving keeps both media types
    /// visible in the first screenful, which is the whole point of running
    /// the browse through the multi-search surface.
    func browse(genre: SearchModel.Genre) async {
        apiError = false
        // Set up front, not on success: the error state names the genre
        // and its Retry button re-runs it, and both read this. Assigning
        // it only after a successful fetch left a failed browse pointing
        // at whichever genre last worked, so Retry silently re-ran the
        // wrong one.
        activeGenre = genre
        isSearching = true
        defer { isSearching = false }

        do {
            let page = try await fetchGenrePage(genre, page: 1)
            selectedChooser = .all
            genrePage = 1
            genreHasMore = page.hasMore
            results = Self.interleaved(page.feeds)
        } catch {
            apiError = true
        }
    }

    /// Appends the genre's next Discover page.
    ///
    /// Only the footer shows a spinner: swapping the whole screen to the
    /// loading skeleton would throw away the user's scroll position and the
    /// results they were reading, which is the opposite of what "show me
    /// more" asks for. A failure just re-enables the button — the results
    /// already on screen are untouched.
    func loadMoreGenreResults() async {
        guard let genre = activeGenre, genreHasMore, !isLoadingMoreGenre else { return }
        isLoadingMoreGenre = true
        defer { isLoadingMoreGenre = false }

        let next = genrePage + 1
        do {
            let page = try await fetchGenrePage(genre, page: next)
            genrePage = next
            genreHasMore = page.hasMore
            // Dedupe against what's already listed, not just within the new
            // page: Discover sorts by popularity, which drifts between
            // requests, so a title on page 1 can reappear on page 2.
            let existing = Set((results ?? []).compactMap(\.id))
            let appended = Self.interleaved(page.feeds, excluding: existing)
            guard !appended.isEmpty else {
                // Nothing new came back — treat the feed as exhausted rather
                // than leaving a button that does nothing.
                genreHasMore = false
                return
            }
            results = (results ?? []) + appended
        } catch {
            // Leave `genrePage` where it was so the button retries this page.
        }
    }

    /// One Discover page for every media type the genre exists on.
    private func fetchGenrePage(_ genre: SearchModel.Genre,
                                page: Int) async throws -> (feeds: [[Result]], hasMore: Bool) {
        try await withThrowingTaskGroup(of: (Int, [Result], Int).self) { group in
            for (offset, query) in genre.queries.enumerated() {
                let (screenType, genreID) = query
                group.addTask { [service] in
                    let response = try await service.fetchByGenre(screenType: screenType,
                                                                  genreID: genreID,
                                                                  page: page)
                    return (offset, Self.postered(response.results, as: screenType),
                            response.total_pages ?? 1)
                }
            }
            // Re-sorted by the task's own index: a task group yields in
            // completion order, and letting network timing decide which
            // media type leads the list would make the same tap produce
            // a different order each time.
            var collected: [(Int, [Result], Int)] = []
            for try await feed in group { collected.append(feed) }
            collected.sort { $0.0 < $1.0 }
            // More to come while *any* side still has pages — the interleave
            // already copes with one feed running out before the other.
            // TMDB refuses pages past 500, so stop there regardless.
            let hasMore = collected.contains { page < min($0.2, 500) }
            return (collected.map(\.1), hasMore)
        }
    }

    /// Round-robins across the feeds, keeping each feed's internal order.
    /// `excluding` holds ids already on screen, for the paged append.
    private nonisolated static func interleaved(_ feeds: [[Result]],
                                                excluding: Set<Int> = []) -> [Result] {
        var out: [Result] = []
        var seen = excluding
        let longest = feeds.map(\.count).max() ?? 0

        for index in 0..<longest {
            for feed in feeds where index < feed.count {
                let result = feed[index]
                // `Result` compares and hashes on id alone, so two entries
                // sharing an id are one row as far as `ForEach` is
                // concerned — a duplicate would collapse the list.
                guard let id = result.id, seen.insert(id).inserted else { continue }
                out.append(result)
            }
        }
        return out
    }

    // MARK: - Trending

    /// Fills the start screen's poster row. Fetched once per view-model
    /// lifetime (i.e. once per app session, since `ContentView` owns the
    /// instance) — trending is a daily feed, so re-fetching every time the
    /// user backs out of a search would spend requests to show the same
    /// posters. A previous failure is retryable; a success is not re-run.
    func loadTrendingIfNeeded() async {
        guard !model.hasTrending, !isLoadingTrending else { return }
        await loadTrending()
    }

    /// Unconditional fetch behind the error state's Retry button.
    func loadTrending() async {
        isLoadingTrending = true
        trendingFailed = false
        defer { isLoadingTrending = false }

        do {
            // Both feeds up front so flipping the scope toggle is instant —
            // a second spinner on the first tap of "TV Series" would undercut
            // the point of putting the toggle there.
            async let movies = service.fetchTrendingMovies(page: 1)
            async let series = service.fetchTrendingSeries(page: 1)
            let (movieFeed, seriesFeed) = try await (movies, series)

            trendingMovies = Self.postered(movieFeed.results, as: .movie)
            trendingSeries = Self.postered(seriesFeed.results, as: .tv)
        } catch {
            trendingFailed = true
        }
    }

    /// Drops entries with no poster art (a blank card in a poster row reads
    /// as a broken image, not as missing metadata) and stamps `media_type`,
    /// which the trending endpoints omit — without it `getMediaType()`
    /// falls through to "Actor" and the tap would open the wrong screen.
    private nonisolated static func postered(_ results: [Result],
                                 as screenType: ScreenTypes) -> [Result] {
        results
            .filter { $0.poster_path != nil }
            .map { result in
                var stamped = result
                stamped.media_type = screenType.rawValue
                return stamped
            }
    }

    func removeRecentSearch(_ query: String) {
        SearchHistoryManager.removeSearch(query)
        model.recentSearches = SearchHistoryManager.recentSearches
    }

    func clearRecentSearches() {
        SearchHistoryManager.clearAll()
        model.recentSearches = SearchHistoryManager.recentSearches
    }
    
    private func cleanUpResults(results: SearchResponse?) {
        
        self.results = results?.results?.filter { $0.poster_path != nil && $0.media_type != "person" ||
                                                  $0.profile_path != nil && $0.media_type == "person" }
    }
}

extension SearchViewModel {
    
    var searchResponse: SearchResponse? {
        get { model.searchResponse }
        set { model.searchResponse = newValue }
    }
    
    var results: [Result]? {
        get { model.results }
        set { model.results = newValue }
    }
    
    var filteredResults: [Result] {
        get { model.filteredResults }
        set { model.filteredResults = newValue }
    }

    var selectedChooser: SearchModel.SearchChooserOptions {
        get { model.selectedChooser }
        set { model.selectedChooser = newValue }
    }

    var query: String {
        get { model.query }
        set { model.query = newValue }
    }

    var recentSearches: [String] {
        get { model.recentSearches }
        set { model.recentSearches = newValue }
    }

    var trendingMovies: [Result] {
        get { model.trendingMovies }
        set { model.trendingMovies = newValue }
    }

    var trendingSeries: [Result] {
        get { model.trendingSeries }
        set { model.trendingSeries = newValue }
    }

    var trendingScope: SearchModel.TrendingScope {
        get { model.trendingScope }
        set { model.trendingScope = newValue }
    }

    var isLoadingTrending: Bool {
        get { model.isLoadingTrending }
        set { model.isLoadingTrending = newValue }
    }

    var trendingFailed: Bool {
        get { model.trendingFailed }
        set { model.trendingFailed = newValue }
    }

    var activeGenre: SearchModel.Genre? {
        get { model.activeGenre }
        set { model.activeGenre = newValue }
    }

    var genrePage: Int {
        get { model.genrePage }
        set { model.genrePage = newValue }
    }

    var genreHasMore: Bool {
        get { model.genreHasMore }
        set { model.genreHasMore = newValue }
    }

    var isLoadingMoreGenre: Bool {
        get { model.isLoadingMoreGenre }
        set { model.isLoadingMoreGenre = newValue }
    }

    var trending: [Result] { model.trending }

    var hasTrending: Bool { model.hasTrending }
}
