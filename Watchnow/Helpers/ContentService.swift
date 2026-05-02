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

    private let service: ContentService

    // Non-published so flipping it doesn't trigger a SwiftUI re-render mid-scroll.
    // Used to block re-entry into loadMoreContent while a fetch is in-flight.
    private var loadingSections: Set<ViewSections> = []

    init(service: ContentService) {
        self.service = service
    }

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
        }
        apiError = false
        loadingCompleted = false

        let svc = service   // capture Sendable reference for child tasks
        async let t = svc.fetchTrending(page: 1)
        async let p = svc.fetchPopular(page: 1)
        async let s = svc.fetchUpcomingOrAiring(page: 1)
        async let l = svc.fetchLatest(page: 1)
        async let r5 = svc.fetchTopRated(page: 1)

        if let r = try? await t  { trending  = ContentListResult(result: r) } else { apiError = true }
        if let r = try? await p  { popular   = ContentListResult(result: r) } else { apiError = true }
        if let r = try? await s  { special   = ContentListResult(result: r) } else { apiError = true }
        if let r = try? await l  { latest    = ContentListResult(result: r) } else { apiError = true }
        if let r = try? await r5 { topRated  = ContentListResult(result: r) } else { apiError = true }

        loadingCompleted = true
    }

    // MARK: - Pagination

    func canLoadMoreContent(section: ViewSections) -> Bool {
        switch section {
        case .trendingMovies, .trendingSeries:      return trending?.canLoadMoreContent() ?? false
        case .popularMovies, .popularSeries:        return popular?.canLoadMoreContent()  ?? false
        case .upcomingMovies, .airingTodaySeries:   return special?.canLoadMoreContent()  ?? false
        case .latestMovies, .latestSeries:          return latest?.canLoadMoreContent()   ?? false
        case .topRatedMovies, .topRatedSeries:      return topRated?.canLoadMoreContent() ?? false
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
