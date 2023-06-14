//
//  SeriesViewModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 30/7/22.
//

import Foundation

@MainActor
class SeriesViewModel: ObservableObject, BaseViewModelProtocol {
    
    @Published private(set) var popularSeries: PopularSeriesModel?
    @Published private(set) var airingTodaySeries: AiringTodaySeriesModel?
    @Published private(set) var trendingSeries: TrendingSeriesModel? {
        didSet {
            self.featuredSerie = trendingSeries?.results[randomFeaturedIndex]
        }
    }
    @Published private(set) var latestSeries: PopularSeriesModel?
    
    @Published private(set) var popularSeriesCurrentPage = 1
    @Published private(set) var airingTodaySeriesCurrentPage = 1
    @Published private(set) var trendingSeriesCurrentPage = 1
    @Published private(set) var latestSeriesCurrentPage = 1
    
    private let service: SerieService = .init()
    let randomFeaturedIndex = Int.random(in: 0...19)
    var featuredSerie: Result?
    
    func loadMoreContent(section: ViewSections) {
        
        guard canLoadMoreContent(section: section) else {
            return
        }
        
        switch section {
        case .popularSeries:
            popularSeriesCurrentPage += 1
        case .airingTodaySeries:
            airingTodaySeriesCurrentPage += 1
        case .trendingSeries:
            trendingSeriesCurrentPage += 1
        case .latestSeries:
            latestSeriesCurrentPage += 1
        default:
            break
        }
    }
    
    func canLoadMoreContent(section: ViewSections) -> Bool {
        
        switch section {
        case .popularSeries:
            guard let totalPages = popularSeries?.total_pages else {
                return false
            }
            return popularSeriesCurrentPage < totalPages
        case .airingTodaySeries:
            guard let totalPages = popularSeries?.total_pages else {
                return false
            }
            return airingTodaySeriesCurrentPage < totalPages
        case .trendingSeries:
            guard let totalPages = popularSeries?.total_pages else {
                return false
            }
            return trendingSeriesCurrentPage < totalPages
        case .latestSeries:
            guard let totalPages = latestSeries?.total_pages else {
                return false
            }
            return latestSeriesCurrentPage < totalPages
        default:
            return false
        }
    }
    
    func getTrendingSeries(page: Int = 1) async {
        
        do {
            if page == 1 {
                self.trendingSeries = try await service.fetchTrendingSeries(page: page)
            } else {
                self.trendingSeries?.results.append(contentsOf: try await service.fetchTrendingSeries(page: page).results)
            }
        } catch {
            print(error)
        }
    }
    
    func getPopularSeries(page: Int = 1) async {
        
        do {
            if page == 1 {
                self.popularSeries = try await service.fetchPopularSeries(page: page)
            } else {
                self.popularSeries?.results.append(contentsOf: try await service.fetchPopularSeries(page: page).results)
            }
        } catch {
            print(error)
        }
    }
    
    func getAiringTodaySeries(page: Int = 1) async {
        
        do {
            if page == 1 {
                self.airingTodaySeries = try await service.fetchAiringTodaySeries(page: page)
            } else {
                self.airingTodaySeries?.results.append(contentsOf: try await service.fetchAiringTodaySeries(page: page).results)
            }
        } catch {
            print(error)
        }
    }
    
    func getLatestSeries(page: Int = 1) async {
        
        do {
            if page == 1 {
                self.latestSeries = try await service.fetchLatestSeries(page: page)
            } else {
                self.latestSeries?.results.append(contentsOf: try await service.fetchLatestSeries(page: page).results)
            }
        } catch {
            print(error)
        }
    }
    
    var finishedLoadingContent: Bool {
        return (popularSeries?.results.isEmpty == false &&
                airingTodaySeries?.results.isEmpty == false &&
                trendingSeries?.results.isEmpty == false &&
                latestSeries?.results.isEmpty == false)
    }
}
