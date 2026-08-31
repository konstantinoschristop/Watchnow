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
            let feeds = try await withThrowingTaskGroup(of: (Int, [Result]).self) { group in
                for (offset, query) in genre.queries.enumerated() {
                    let (screenType, genreID) = query
                    group.addTask { [service] in
                        let response = try await service.fetchByGenre(screenType: screenType,
                                                                      genreID: genreID,
                                                                      page: 1)
                        return (offset, Self.postered(response.results, as: screenType))
                    }
                }
                // Re-sorted by the task's own index: a task group yields in
                // completion order, and letting network timing decide which
                // media type leads the list would make the same tap produce
                // a different order each time.
                var collected: [(Int, [Result])] = []
                for try await feed in group { collected.append(feed) }
                return collected.sorted { $0.0 < $1.0 }.map(\.1)
            }

            selectedChooser = .all
            results = Self.interleaved(feeds)
        } catch {
            apiError = true
        }
    }

    /// Round-robins across the feeds, keeping each feed's internal order.
    private nonisolated static func interleaved(_ feeds: [[Result]]) -> [Result] {
        guard feeds.count > 1 else { return feeds.first ?? [] }

        var out: [Result] = []
        var seen = Set<Int>()
        let longest = feeds.map(\.count).max() ?? 0

        for index in 0..<longest {
            for feed in feeds where index < feed.count {
                let result = feed[index]
                // Movie and TV genre queries can surface the same TMDB id
                // for unrelated titles only rarely, but `Result` hashes on
                // id alone — a duplicate would collapse the `ForEach` that
                // renders these rows.
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

    var trending: [Result] { model.trending }

    var hasTrending: Bool { model.hasTrending }
}
