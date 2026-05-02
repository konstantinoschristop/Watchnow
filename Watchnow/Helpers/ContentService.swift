//
//  ContentService.swift
//  Watchnow
//
//  Created by k.christopoulos on 28/9/25.
//

import SwiftUI

@MainActor
protocol BaseViewModelProtocol {

    func loadMoreContent(section: ViewSections)
    func canLoadMoreContent(section: ViewSections) -> Bool
}

protocol ContentService: AnyObject, Sendable {
    func fetchTrending(page: Int) async throws -> GenericResultResponse
    func fetchPopular(page: Int) async throws -> GenericResultResponse
    func fetchUpcomingOrAiring(page: Int) async throws -> GenericResultResponse
    func fetchLatest(page: Int) async throws -> GenericResultResponse
    func fetchTopRated(page: Int) async throws -> GenericResultResponse

    /// Screen-type-specific so the Movies tab fetches movie providers
    /// and Series fetches TV providers. The provider IDs are
    /// content-type-scoped on TMDB's side too — Netflix has different
    /// IDs for its movie catalogue vs. its TV catalogue.
    var screenType: ScreenTypes { get }
}

@MainActor
class BaseContentViewModel: ObservableObject, BaseViewModelProtocol {

    @Published var apiError = false
    @Published var loadingCompleted = false

    @Published var trending: ContentListResult? {
        didSet { featuredResult = trending?.getResults().prefix(5).map(\.self) }
    }
    @Published var popular: ContentListResult?
    @Published var special: ContentListResult?   // "upcoming" for movies, "airingToday" for series
    @Published var latest: ContentListResult?
    @Published var topRated: ContentListResult?
    @Published var featuredResult: [Result]?

    /// Region-scoped catalogue of streaming services, sorted by TMDB's
    /// display priority (Netflix / Apple TV+ / Disney+ at the top, niche
    /// services at the bottom). Capped at 20 — past that the row stops
    /// being useful and starts surfacing services nobody recognises.
    @Published var providers: [WatchProvider]?

    /// Currently picked streaming-service chip. Drives the inline
    /// results row underneath the chip bar. Auto-populated to Netflix
    /// (or the first provider in the region) when `loadContent` finishes.
    @Published var selectedProvider: WatchProvider?

    /// Titles available on `selectedProvider`. Refreshed every time the
    /// user taps a different chip — empty array, not nil, so the UI
    /// can distinguish "no selection yet" (selectedProvider == nil) from
    /// "selected but loading" (results.isEmpty + isLoadingProviderResults).
    @Published var providerResults: [Result] = []
    @Published var isLoadingProviderResults: Bool = false

    /// True while the section can still load more pages from the
    /// discover endpoint. Flips to false once we've appended an empty
    /// page or hit `total_pages`. Drives whether the trailing
    /// load-more button is rendered at all.
    @Published var canLoadMoreProviderResults: Bool = false

    /// 1-based page tracker for `selectedProvider`. Reset to 1 on every
    /// chip switch so we don't accidentally pick up where the previous
    /// provider's pagination left off.
    private var providerResultsPage: Int = 1
    private var isLoadingMoreProviderResults: Bool = false

    private let service: ContentService
    /// Used for non-list fetches (providers, etc.) that don't fit the
    /// `ContentService` protocol. Concrete `ServiceInvocation` is fine
    /// here because there are no current tests stubbing out provider
    /// fetching, and the dependency stays internal to this view model.
    private let extraService = ServiceInvocation()

    // Non-published so flipping it doesn't trigger a SwiftUI re-render mid-scroll.
    // Used to block re-entry into loadMoreContent while a fetch is in-flight.
    private var loadingSections: Set<ViewSections> = []

    init(service: ContentService) {
        self.service = service
    }

    /// Exposed so views (the streaming-services tile row, the discover sheet)
    /// know which content type to query for and what region to scope to.
    var screenType: ScreenTypes { service.screenType }
    var currentRegion: String { Locale.current.region?.identifier ?? "US" }

    // MARK: - Load

    /// Fetches all 4 sections concurrently.
    /// - Parameter resetFirst: Pass `true` when retrying after an error to reset
    ///   the UI back to placeholder state. Omit (or pass `false`) for pull-to-refresh
    ///   so existing content stays visible while new data loads.
    func loadContent(resetFirst: Bool = false) async {
        if resetFirst {
            trending = nil
            popular = nil
            special = nil
            latest = nil
            topRated = nil
            providers = nil
        }
        apiError = false
        loadingCompleted = false

        let svc = service   // capture Sendable reference for child tasks
        let region = currentRegion
        let type = screenType
        let extra = extraService
        async let t  = svc.fetchTrending(page: 1)
        async let p  = svc.fetchPopular(page: 1)
        async let s  = svc.fetchUpcomingOrAiring(page: 1)
        async let l  = svc.fetchLatest(page: 1)
        async let r5 = svc.fetchTopRated(page: 1)
        async let pr = extra.fetchProviders(screenType: type, region: region)

        if let r = try? await t  { trending  = ContentListResult(result: r) } else { apiError = true }
        if let r = try? await p  { popular   = ContentListResult(result: r) } else { apiError = true }
        if let r = try? await s  { special   = ContentListResult(result: r) } else { apiError = true }
        if let r = try? await l  { latest    = ContentListResult(result: r) } else { apiError = true }
        if let r = try? await r5 { topRated  = ContentListResult(result: r) } else { apiError = true }
        // Providers failure is *soft* — it just means the streaming-services
        // tile row stays empty. We don't flip apiError, since the rest of the
        // feed is still fully usable without it.
        if let r = try? await pr {
            providers = (r.results ?? [])
                .sorted { ($0.display_priority ?? Int.max) < ($1.display_priority ?? Int.max) }
                .prefix(20)
                .map { $0 }

            // Auto-select Netflix if it's available in the region; otherwise
            // fall back to whichever provider TMDB ranks highest. The inline
            // results row should never look "empty" when we could have shown
            // something useful by default.
            await autoSelectProvider()
        }

        loadingCompleted = true
    }

    // MARK: - Streaming services

    /// Picks an initial provider on tab load. Netflix has provider_id 8
    /// across both movie and TV catalogues on TMDB and is the most likely
    /// service users have a subscription to globally, so we prefer it.
    /// Anywhere it isn't carried, we fall back to the highest-priority
    /// provider in the region.
    private func autoSelectProvider() async {
        guard let providers, selectedProvider == nil else { return }
        let netflix = providers.first { $0.provider_id == 8 }
        if let target = netflix ?? providers.first {
            await selectProvider(target)
        }
    }

    /// Switches the inline streaming-services row to a new provider and
    /// refetches results. No-ops when the user re-taps the same chip.
    /// Also resets the pagination tracker so the new provider's row
    /// starts from page 1 regardless of where the previous provider's
    /// pagination got to.
    func selectProvider(_ provider: WatchProvider) async {
        if selectedProvider?.id == provider.id, !providerResults.isEmpty { return }
        selectedProvider = provider
        providerResults = []
        providerResultsPage = 1
        canLoadMoreProviderResults = false
        isLoadingProviderResults = true
        defer { isLoadingProviderResults = false }

        do {
            let response = try await extraService.fetchByProvider(
                screenType: screenType,
                providerID: provider.provider_id,
                region: currentRegion,
                page: 1
            )
            providerResults = response.results.map { result in
                var r = result
                r.media_type = screenType == .movie ? "movie" : "tv"
                return r
            }
            canLoadMoreProviderResults = !providerResults.isEmpty
                                          && 1 < (response.total_pages ?? 1)
        } catch {
            // Soft-fail — empty list is the user-visible result. We don't
            // raise apiError because the rest of the feed is fine.
            providerResults = []
            canLoadMoreProviderResults = false
        }
    }

    /// Appends the next page of results for the currently selected
    /// provider. Triggered by the overscroll-to-load-more gesture on
    /// the streaming-services row's `StretchingActionScrollView`.
    /// Re-entry guarded so a fast user can't queue up multiple
    /// concurrent fetches by overscrolling repeatedly.
    func loadMoreProviderResults() async {
        guard canLoadMoreProviderResults,
              !isLoadingMoreProviderResults,
              let provider = selectedProvider else { return }

        isLoadingMoreProviderResults = true
        defer { isLoadingMoreProviderResults = false }

        let nextPage = providerResultsPage + 1
        do {
            let response = try await extraService.fetchByProvider(
                screenType: screenType,
                providerID: provider.provider_id,
                region: currentRegion,
                page: nextPage
            )
            let typed = response.results.map { result -> Result in
                var r = result
                r.media_type = screenType == .movie ? "movie" : "tv"
                return r
            }
            providerResults.append(contentsOf: typed)
            providerResultsPage = nextPage
            canLoadMoreProviderResults = !typed.isEmpty
                                          && nextPage < (response.total_pages ?? 1)
        } catch {
            canLoadMoreProviderResults = false
        }
    }

    // MARK: - Pagination

    func canLoadMoreContent(section: ViewSections) -> Bool {
        switch section {
        case .trendingMovies, .trendingSeries:      return trending?.canLoadMoreContent() ?? false
        case .popularMovies, .popularSeries:        return popular?.canLoadMoreContent()  ?? false
        case .upcomingMovies, .airingTodaySeries:   return special?.canLoadMoreContent()  ?? false
        case .latestMovies, .latestSeries:          return latest?.canLoadMoreContent()   ?? false
        case .topRatedMovies, .topRatedSeries:      return topRated?.canLoadMoreContent() ?? false
        // Streaming-services row doesn't paginate through the carousel
        // mechanism — pagination lives inside the provider results sheet.
        case .streamingServicesMovies, .streamingServicesSeries: return false
        }
    }

    func loadMoreContent(section: ViewSections) {
        guard !loadingSections.contains(section) else { return }
        loadingSections.insert(section)

        switch section {
        case .trendingMovies, .trendingSeries:
            loadMore(section: section, list: trending,  fetcher: service.fetchTrending)          { [weak self] in self?.trending  = $0 }
        case .popularMovies, .popularSeries:
            loadMore(section: section, list: popular,   fetcher: service.fetchPopular)           { [weak self] in self?.popular   = $0 }
        case .upcomingMovies, .airingTodaySeries:
            loadMore(section: section, list: special,   fetcher: service.fetchUpcomingOrAiring)  { [weak self] in self?.special   = $0 }
        case .latestMovies, .latestSeries:
            loadMore(section: section, list: latest,    fetcher: service.fetchLatest)            { [weak self] in self?.latest    = $0 }
        case .topRatedMovies, .topRatedSeries:
            loadMore(section: section, list: topRated,  fetcher: service.fetchTopRated)          { [weak self] in self?.topRated  = $0 }
        case .streamingServicesMovies, .streamingServicesSeries:
            // No-op — see comment on canLoadMoreContent above. Release
            // the loading lock so a future call can still proceed.
            loadingSections.remove(section)
        }
    }

    // MARK: - Helpers

    private func loadMore(
        section: ViewSections,
        list: ContentListResult?,
        fetcher: @escaping (Int) async throws -> GenericResultResponse,
        assign: @escaping (ContentListResult?) -> Void
    ) {
        var updated = list
        updated?.incrementCurrentPage()
        guard let page = updated?.currentPage else {
            loadingSections.remove(section)
            return
        }
        Task { [weak self] in
            defer { self?.loadingSections.remove(section) }
            do {
                let fetched = try await fetcher(page)
                updated?.appendResult(fetched)
                assign(updated)
            } catch {
                self?.apiError = true
            }
        }
    }

    var finishedLoadingContent: Bool { loadingCompleted }
}
