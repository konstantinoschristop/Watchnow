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

    /// The region's streaming services, curated the same way as Settings
    /// and onboarding (`StreamingProviderCatalog`): the subscriptions people
    /// mean by "what I have", in a fixed order.
    ///
    /// TMDB's own `display_priority` used to decide this, capped at 20. That
    /// ranking puts storefronts and niche services first — Plex, JustWatch
    /// TV, Apple TV Store — and HBO Max (id 1899) 28th in Greece, 52nd in the
    /// US, so it never made the row. It's only the fallback now, for a
    /// region where none of the curated services exist.
    ///
    /// The services the user has (`StreamingPreferences`) come first.
    @Published var providers: [WatchProvider]?

    /// `providers` before the user's own services are moved to the front.
    /// Kept so a change to theirs re-sorts from the curated order rather
    /// than from the last sort — a service they drop goes back to its place
    /// instead of lingering at the front.
    private var regionProviders: [WatchProvider] = []

    /// Currently picked streaming-service chip. Drives the inline
    /// results row underneath the chip bar. Auto-populated to the user's
    /// first service (or Netflix, or the region's first) when `loadContent`
    /// finishes.
    @Published var selectedProvider: WatchProvider?

    /// Titles available on `selectedProvider`. Refreshed every time the
    /// user taps a different chip — empty array, not nil, so the UI
    /// can distinguish "no selection yet" (selectedProvider == nil) from
    /// "selected but loading" (results.isEmpty + isLoadingProviderResults).
    @Published var providerResults: [Result] = []
    @Published var isLoadingProviderResults: Bool = false
    /// How many titles TMDB lists for `selectedProvider` — the size of the
    /// whole catalogue the row is the first page of. nil until it's known.
    @Published var providerResultsTotal: Int?

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
            let curated = StreamingProviderCatalog.curated(from: r.results)
            regionProviders = curated.isEmpty
                ? (r.results ?? [])
                    .sorted { ($0.display_priority ?? Int.max) < ($1.display_priority ?? Int.max) }
                    .prefix(20)
                    .map { $0 }
                : curated
            providers = StreamingProviderCatalog.prioritized(regionProviders,
                                                             subscribed: Set(StreamingPreferences.providerIDs))

            // Auto-select the user's first service; otherwise Netflix, or
            // whichever provider leads the list. The inline results row
            // should never look "empty" when we could have shown something
            // useful by default.
            await autoSelectProvider()
        }

        loadingCompleted = true
    }

    // MARK: - Streaming services

    /// Picks an initial provider on tab load: the first of the user's own
    /// services, which lead the chip bar — preselecting anything else would
    /// open the row on a chip halfway along it. Without any, Netflix: it
    /// has provider_id 8 across both movie and TV catalogues on TMDB and is
    /// the most likely subscription globally. Anywhere it isn't carried,
    /// the first provider in the list.
    private func autoSelectProvider() async {
        guard let providers, selectedProvider == nil else { return }
        let subscribed = Set(StreamingPreferences.providerIDs)
        let target = providers.first { subscribed.contains($0.provider_id) }
            ?? providers.first { $0.provider_id == 8 }
            ?? providers.first
        if let target {
            await selectProvider(target)
        }
    }

    /// Re-sorts the chip bar after the user changes their services — in
    /// Settings, or on another device via iCloud. The selection stays put:
    /// the row they're looking at shouldn't swap under them because they
    /// ticked a box somewhere else.
    func applySubscribedOrder() {
        guard providers != nil else { return }
        let ordered = StreamingProviderCatalog.prioritized(regionProviders,
                                                           subscribed: Set(StreamingPreferences.providerIDs))
        if ordered != providers { providers = ordered }
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
        providerResultsTotal = nil
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
            providerResultsTotal = response.total_results
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
