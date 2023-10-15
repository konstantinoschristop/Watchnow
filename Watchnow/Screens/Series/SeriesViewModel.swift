//
//  SeriesViewModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 30/7/22.
//

import Foundation

@MainActor
class SeriesViewModel: ObservableObject, BaseViewModelProtocol {
    
    @Published var model: SeriesModel
    @Published var apiError: Bool = false
    private let service: SerieService
    
    init(model: SeriesModel,
         service: SerieService = SerieService()) {
        
        self.model = model
        self.service = service
    }
    
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
            apiError = true
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
            apiError = true
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
            apiError = true
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
            apiError = true
        }
    }
}

extension SeriesViewModel {
    
    var popularSeries: GenericReultResponse? {
        get { model.popularSeries }
        set { model.popularSeries = newValue }
    }
    
    var airingTodaySeries: GenericReultResponse? {
        get { model.airingTodaySeries }
        set { model.airingTodaySeries = newValue }
    }
    
    var trendingSeries: GenericReultResponse? {
        get { model.trendingSeries }
        set { model.trendingSeries = newValue }
    }
    
    var latestSeries: GenericReultResponse? {
        get { model.latestSeries }
        set { model.latestSeries = newValue }
    }
    
    var popularSeriesCurrentPage: Int {
        get { model.popularSeriesCurrentPage }
        set { model.popularSeriesCurrentPage = newValue }
    }
    
    var airingTodaySeriesCurrentPage: Int {
        get { model.airingTodaySeriesCurrentPage }
        set { model.airingTodaySeriesCurrentPage = newValue }
    }
    
    var trendingSeriesCurrentPage: Int {
        get { model.trendingSeriesCurrentPage }
        set { model.trendingSeriesCurrentPage = newValue }
    }
    
    var latestSeriesCurrentPage: Int {
        get { model.latestSeriesCurrentPage }
        set { model.latestSeriesCurrentPage = newValue }
    }
    
    var featuredSerie: Result? {
        get { model.featuredSerie }
        set { model.featuredSerie = newValue }
    }
    
    var finishedLoadingContent: Bool {
        return (popularSeries?.results.isEmpty == false &&
                airingTodaySeries?.results.isEmpty == false &&
                trendingSeries?.results.isEmpty == false &&
                latestSeries?.results.isEmpty == false)
    }
}
