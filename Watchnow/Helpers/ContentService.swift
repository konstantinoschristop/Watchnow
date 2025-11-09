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

@MainActor
protocol ContentService {
    func fetchTrending(page: Int) async throws -> GenericReultResponse
    func fetchPopular(page: Int) async throws -> GenericReultResponse
    func fetchUpcomingOrAiring(page: Int) async throws -> GenericReultResponse
    func fetchLatest(page: Int) async throws -> GenericReultResponse
}

@MainActor
class BaseContentViewModel: ObservableObject, BaseViewModelProtocol {
    
    @Published var apiError = false
    
    @Published var trending: ContentListResult? {
        didSet {
            featuredResult = trending?.getResults().prefix(5).map(\.self)
        }
    }
    @Published var popular: ContentListResult?
    @Published var special: ContentListResult?   // "upcoming" for movies, "airingToday" for series
    @Published var latest: ContentListResult?
    @Published var featuredResult: [Result]?
    
    private let service: ContentService
    private let randomFeaturedIndex = Int.random(in: 0...19)
    
    init(service: ContentService) {
        self.service = service
    }
    
    func loadContent() async {
        trending = await fetch(list: trending, fetcher: service.fetchTrending, page: 1)
        popular = await fetch(list: popular, fetcher: service.fetchPopular, page: 1)
        special = await fetch(list: special, fetcher: service.fetchUpcomingOrAiring, page: 1)
        latest = await fetch(list: latest, fetcher: service.fetchLatest, page: 1)
    }
    
    func canLoadMoreContent(section: ViewSections) -> Bool {
        switch section {
        case .trendingMovies, .trendingSeries:
            return trending?.canLoadMoreContent() ?? false
        case .popularMovies, .popularSeries:
            return popular?.canLoadMoreContent() ?? false
        case .upcomingMovies, .airingTodaySeries:
            return special?.canLoadMoreContent() ?? false
        case .latestMovies, .latestSeries:
            return latest?.canLoadMoreContent() ?? false
        }
    }
    
    func loadMoreContent(section: ViewSections) {
        switch section {
        case .trendingMovies, .trendingSeries:
            loadMore(list: trending, fetcher: service.fetchTrending) { [weak self] updated in
                self?.trending = updated
            }
        case .popularMovies, .popularSeries:
            loadMore(list: popular, fetcher: service.fetchPopular) { [weak self] updated in
                self?.popular = updated
            }
        case .upcomingMovies, .airingTodaySeries:
            loadMore(list: special, fetcher: service.fetchUpcomingOrAiring) { [weak self] updated in
                self?.special = updated
            }
        case .latestMovies, .latestSeries:
            loadMore(list: latest, fetcher: service.fetchLatest) { [weak self] updated in
                self?.latest = updated
            }
        }
    }
    
    // MARK: - Helpers
    private func fetch(list: ContentListResult?, fetcher: (Int) async throws -> GenericReultResponse, page: Int) async -> ContentListResult? {
        do {
            let fetched = try await fetcher(page)
            if page == 1 {
                return ContentListResult(result: fetched)
            } else {
                var updated = list
                updated?.appendResult(fetched)
                return updated
            }
        } catch {
            apiError = true
            return list
        }
    }
    
    private func loadMore(
        list: ContentListResult?,
        fetcher: @escaping (Int) async throws -> GenericReultResponse,
        assign: @escaping (ContentListResult?) -> Void
    ) {
        var updated = list
        updated?.incrementCurrentPage()
        if let page = updated?.currentPage {
            Task {
                let newList = await fetch(list: updated, fetcher: fetcher, page: page)
                assign(newList)
            }
        }
    }
    
    var finishedLoadingContent: Bool {
        return (special?.result.results.isEmpty == false &&
                popular?.result.results.isEmpty == false &&
                trending?.result.results.isEmpty == false &&
                latest?.result.results.isEmpty == false)
    }
}
