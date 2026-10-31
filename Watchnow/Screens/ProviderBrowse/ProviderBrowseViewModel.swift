//
//  ProviderBrowseViewModel.swift
//  Watchnow
//
//  Pages through one streaming service's catalogue as the grid scrolls,
//  and starts over from page one whenever a filter changes.
//

import Foundation

@MainActor
final class ProviderBrowseViewModel: ObservableObject {

    enum Phase: Equatable {
        case loading, loaded, empty, failed
    }

    /// The services the title menu switches between — the same curated list
    /// the feed's chip bar shows.
    let providers: [WatchProvider]
    let region: String

    @Published private(set) var provider: WatchProvider
    @Published private(set) var query: ProviderCatalogQuery
    @Published private(set) var results: [Result] = []
    @Published private(set) var phase: Phase = .loading
    /// TMDB's count for the whole catalogue under the current filters. It
    /// includes the few entries the grid drops for having no poster, so it
    /// reads as a size, not as an exact tally of the cells.
    @Published private(set) var totalResults: Int?
    @Published private(set) var canLoadMore = false
    @Published private(set) var isLoadingMore = false

    /// True while a new filter's first page is on its way and the previous
    /// filter's titles are still on screen. A filter tap used to clear the
    /// grid to a skeleton, which flashed the whole screen for what is, to the
    /// user, a small change; now the old titles dim until the new ones land.
    @Published private(set) var isRefreshing = false
    /// The query `results` answer. Runs behind `query` while refreshing, so
    /// what's drawn from the results — the Top 10, the heading — describes
    /// the titles on screen rather than the ones on their way.
    @Published private(set) var resultsQuery: ProviderCatalogQuery

    /// The titles the hero pages through: the leaders of the service's
    /// catalogue. Changes with the service or media type, not with every
    /// genre or sort — the hero is the service's billboard, and it swapping
    /// its artwork on each filter tap read as noise.
    @Published private(set) var heroTitles: [Result] = []
    private var heroKey: HeroKey?

    /// Movies or series — what `heroTitles` are, which can lag the filter for
    /// a moment after Movies and Series are switched. A tap on the hero opens
    /// the title as what it is.
    var heroScreenType: ScreenTypes { heroKey?.screenType ?? query.screenType }

    private struct HeroKey: Equatable {
        let providerID: Int
        let screenType: ScreenTypes
    }

    // MARK: Search

    /// What's typed in the search field, handed over by `updateSearch(_:)`.
    /// Deliberately not published: the field owns its own text, and
    /// publishing every keystroke re-rendered the whole screen — grid and
    /// all — once per letter.
    private(set) var searchText = ""
    /// Whether the field holds anything: the screen's other mode, where the
    /// grid gives way to search results. Published only when it flips.
    @Published private(set) var isSearching = false
    /// Results for the latest finished search. Left in place while the next
    /// one runs, so typing refines the list rather than flashing a spinner
    /// between keystrokes.
    @Published private(set) var searchResults: ProviderSearchResults?
    @Published private(set) var isSearchLoading = false
    @Published private(set) var searchFailed = false

    private var trimmedSearch: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var searchTask: Task<Void, Never>?

    /// Matches checked for availability per search. Each costs a request,
    /// and TMDB's relevance ranking has put anything worth finding well
    /// inside the first sixteen.
    private let searchCandidateLimit = 16

    /// How close to the end of the grid a cell has to be before its
    /// appearance fetches the next page — about two rows of three, so the
    /// page usually lands before the user reaches the bottom.
    let prefetchDistance = 6

    private let service: ProviderCatalogServiceProtocol
    private var page = 0
    /// Ids already in the grid. Discover sorts by a popularity score that
    /// drifts between requests, so a title on page 1 can turn up again on
    /// page 2 — and `ForEach` can't hold two cells with one id.
    private var seenIDs: Set<Int> = []
    private var loadTask: Task<Void, Never>?

    init(providers: [WatchProvider],
         provider: WatchProvider,
         screenType: ScreenTypes,
         region: String,
         service: ProviderCatalogServiceProtocol = ServiceInvocation()) {
        // The menu must be able to show what's on screen, even if the feed's
        // list somehow lost it.
        self.providers = providers.contains(provider) ? providers : [provider] + providers
        self.provider = provider
        self.region = region
        self.service = service
        let query = ProviderCatalogQuery(providerID: provider.provider_id, screenType: screenType)
        self.query = query
        self.resultsQuery = query
    }

    var genreIDs: [Int] { ProviderCatalogQuery.genreIDs(for: query.screenType) }

    // MARK: - Filters

    func select(provider: WatchProvider) {
        self.provider = provider
        apply { $0.providerID = provider.provider_id }
        // The same words mean a different answer on another service. The
        // last answer goes now rather than when the next lands: its split
        // into "On" and "Not on" is the old service's, and the headings
        // would already name the new one.
        if isSearching {
            searchResults = nil
            scheduleSearch(debounce: false)
        }
    }

    func select(screenType: ScreenTypes) {
        apply { $0 = $0.switching(to: screenType) }
    }

    func select(sort: ProviderBrowseSort) {
        apply { $0.sort = sort }
    }

    /// nil clears the genre filter.
    func select(genreID: Int?) {
        apply { $0.genreID = genreID }
    }

    private func apply(_ change: (inout ProviderCatalogQuery) -> Void) {
        var next = query
        change(&next)
        guard next != query else { return }
        query = next
        reload()
    }

    // MARK: - Loading

    /// First load, from the view's `.task`. Coming back from a details
    /// screen runs the task again; the grid is still there, so it's a no-op.
    func loadIfNeeded() {
        guard loadTask == nil else { return }
        reload()
    }

    /// Starts over at page one for the current query. Whatever was still in
    /// flight for an earlier query is cancelled, and its answer ignored if it
    /// arrives anyway.
    ///
    /// With titles already on screen they stay there, dimmed, until the new
    /// first page replaces them (`isRefreshing`). Only a first load, or one
    /// after an empty or failed list, shows the skeleton.
    func reload() {
        loadTask?.cancel()
        page = 0
        canLoadMore = false
        isLoadingMore = false
        if phase == .loaded, !results.isEmpty {
            isRefreshing = true
        } else {
            results = []
            seenIDs = []
            totalResults = nil
            phase = .loading
        }

        let query = query
        loadTask = Task { await loadPage(after: 0, for: query) }
    }

    /// Called as each cell appears; fetches the next page once the user is
    /// within `prefetchDistance` of the end.
    func loadMoreIfNeeded(at index: Int) {
        guard index >= results.count - prefetchDistance else { return }
        loadMore()
    }

    func loadMore() {
        // Not while refreshing: the titles on screen belong to the previous
        // query, and their next page isn't the one coming.
        guard phase == .loaded, canLoadMore, !isLoadingMore, !isRefreshing else { return }
        isLoadingMore = true

        let query = query
        let page = page
        loadTask = Task { await loadPage(after: page, for: query) }
    }

    /// Fetches the page after `page` and appends what's new.
    ///
    /// A page can add nothing: every entry already listed, or none with a
    /// poster. Nothing new means no new cell appears to ask for the next
    /// page, so the grid would stall with a spinner at the bottom. It reads
    /// on instead — a few pages at most, then treats the catalogue as done.
    private func loadPage(after page: Int, for query: ProviderCatalogQuery) async {
        var next = page + 1
        var added = false
        for _ in 0..<3 {
            let response: GenericResultResponse
            do {
                response = try await service.fetchProviderCatalog(query, region: region, page: next)
            } catch {
                guard isCurrent(query) else { return }
                // A first page that fails is the whole screen failing — the
                // dimmed titles of the previous filter go with it, rather
                // than standing in for an answer that never came. So is a
                // later one that fails with nothing yet listed: the first
                // page added nothing, and this was its read-on. A later page
                // under titles already listed leaves the grid as it was; the
                // next scroll to the bottom tries the same page again.
                if next == 1 || results.isEmpty {
                    results = []
                    seenIDs = []
                    isRefreshing = false
                    canLoadMore = false
                    phase = .failed
                    if next == 1 { dropHeroIfStale(for: query) }
                }
                isLoadingMore = false
                return
            }
            guard isCurrent(query) else { return }

            self.page = next
            if next == 1 {
                // The new query's titles replace the previous one's in a
                // single pass, so the grid never shows a mix of the two.
                results = []
                seenIDs = []
                resultsQuery = query
                totalResults = response.total_results
                isRefreshing = false
                updateHero(from: response, for: query)
            }
            // TMDB refuses any page past 500.
            let lastPage = min(response.total_pages ?? 1, 500)
            let fresh = Self.newEntries(response.results, as: query.screenType, excluding: &seenIDs)
            results += fresh
            canLoadMore = next < lastPage
            added = !fresh.isEmpty
            if added || !canLoadMore { break }
            next += 1
        }
        if !added { canLoadMore = false }
        phase = results.isEmpty ? .empty : .loaded
        isLoadingMore = false
    }

    /// Takes the hero's titles from a first page when it's for a service or
    /// media type the hero isn't showing yet, or when it's the unfiltered
    /// popular list — the service's own headline — or when the hero has
    /// nothing up. A genre or sort applied on top leaves the hero alone.
    private func updateHero(from response: GenericResultResponse, for query: ProviderCatalogQuery) {
        let key = HeroKey(providerID: query.providerID, screenType: query.screenType)
        let isHeadline = query.genreID == nil && query.sort == .popular
        guard key != heroKey || isHeadline || heroTitles.isEmpty else { return }
        let leaders = response.results.filter { $0.poster_path != nil }.prefix(6)
        guard !leaders.isEmpty else {
            dropHeroIfStale(for: query)
            return
        }
        heroTitles = Array(leaders)
        heroKey = key
    }

    /// Takes the hero down when the service or media type has changed and
    /// there's nothing of the new one's to put up — an empty first page, or
    /// one that failed. Left up, the last service's titles cycled under the
    /// new service's name.
    private func dropHeroIfStale(for query: ProviderCatalogQuery) {
        let key = HeroKey(providerID: query.providerID, screenType: query.screenType)
        guard key != heroKey, !heroTitles.isEmpty else { return }
        heroTitles = []
        heroKey = nil
    }

    // MARK: - Search

    /// The field's text, as the user types it.
    func updateSearch(_ text: String) {
        guard text != searchText else { return }
        searchText = text
        let active = !trimmedSearch.isEmpty
        if active != isSearching { isSearching = active }
        scheduleSearch()
    }

    func clearSearch() {
        updateSearch("")
    }

    /// Runs the search for what's typed, a beat after the last keystroke.
    /// A newer keystroke cancels the older search; so does a cleared field.
    ///
    /// Every assignment below is guarded: `@Published` announces a change
    /// on any write, equal or not, and each announcement re-renders the
    /// screen. Unguarded, a keystroke re-rendered it for nothing.
    func scheduleSearch(debounce: Bool = true) {
        searchTask?.cancel()
        if searchFailed { searchFailed = false }
        let text = trimmedSearch
        guard !text.isEmpty else {
            if searchResults != nil { searchResults = nil }
            if isSearchLoading { isSearchLoading = false }
            return
        }

        let provider = provider
        searchTask = Task {
            if debounce {
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
            }
            if !isSearchLoading { isSearchLoading = true }
            defer { if !Task.isCancelled { isSearchLoading = false } }

            do {
                let results = try await search(text, on: provider)
                guard !Task.isCancelled else { return }
                searchResults = results
            } catch {
                guard !Task.isCancelled else { return }
                searchFailed = true
            }
        }
    }

    /// TMDB search, then one availability lookup per match, in parallel.
    /// A lookup that fails counts as "not known to stream here" rather than
    /// failing the search — one bad request shouldn't hide fifteen answers.
    private func search(_ text: String, on provider: WatchProvider) async throws -> ProviderSearchResults {
        let response = try await service.fetchSearchResults(search: text)
        let candidates = (response.results ?? [])
            .filter { ($0.media_type == "movie" || $0.media_type == "tv") && $0.poster_path != nil && $0.id != nil }
            .prefix(searchCandidateLimit)

        let service = service
        let region = region
        let availability = await withTaskGroup(of: (Int, [WatchProvider]).self) { group in
            for (index, candidate) in candidates.enumerated() {
                group.addTask {
                    let type: ScreenTypes = candidate.media_type == "tv" ? .tv : .movie
                    let response = try? await service.fetchWatchProviders(screenType: type,
                                                                          id: String(candidate.id ?? 0))
                    let streaming = (response?.results?[region]?.flatrate ?? []).compactMap { flat -> WatchProvider? in
                        guard let id = flat.providerID, let name = flat.providerName else { return nil }
                        return WatchProvider(provider_id: id, provider_name: name,
                                             logo_path: flat.logoPath, display_priority: flat.displayPriority)
                    }
                    return (index, streaming)
                }
            }
            var byIndex: [Int: [WatchProvider]] = [:]
            for await (index, streaming) in group { byIndex[index] = streaming }
            return byIndex
        }

        var results = ProviderSearchResults(query: text, onService: [], elsewhere: [])
        // Walked in TMDB's relevance order, not in the order lookups returned.
        for (index, candidate) in candidates.enumerated() {
            let streaming = availability[index] ?? []
            if streaming.contains(where: { $0.provider_id == provider.provider_id }) {
                results.onService.append(candidate)
            } else {
                results.elsewhere.append(.init(result: candidate,
                                               streamingOn: preferredService(among: streaming)))
            }
        }
        return results
    }

    /// The service to name for a title that isn't on this one: the first of
    /// the region's curated services that carries it, so the answer is a
    /// service the user is likely to have, or else whatever TMDB lists first.
    private func preferredService(among streaming: [WatchProvider]) -> WatchProvider? {
        let known = providers.first { curated in streaming.contains { $0.provider_id == curated.provider_id } }
        return known ?? streaming.first
    }

    /// Whether a response fetched for `query` still answers what's on screen.
    private func isCurrent(_ query: ProviderCatalogQuery) -> Bool {
        !Task.isCancelled && query == self.query
    }

    /// Drops entries already listed or without poster art (a blank cell
    /// reads as a broken image), and stamps `media_type`, which Discover
    /// omits — the details screen needs it to know what it's opening.
    private nonisolated static func newEntries(_ results: [Result],
                                               as screenType: ScreenTypes,
                                               excluding seen: inout Set<Int>) -> [Result] {
        results.compactMap { result in
            guard let id = result.id, result.poster_path != nil,
                  seen.insert(id).inserted else { return nil }
            var stamped = result
            stamped.media_type = screenType.rawValue
            return stamped
        }
    }
}
