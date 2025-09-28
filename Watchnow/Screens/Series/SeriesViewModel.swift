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
    
    func loadContent() async {
        await getTrendingSeries()
        await getAiringTodaySeries()
        await getPopularSeries()
        await getLatestSeries()
    }
    
    func loadMoreContent(section: ViewSections) {
        
        guard canLoadMoreContent(section: section) else {
            return
        }
        
        switch section {
        case .popularSeries:
            popularSeries?.incrementCurrentPage()
            Task {
                if let newPage = popularSeries?.currentPage {
                    await getPopularSeries(page: newPage)
                }
            }
        case .airingTodaySeries:
            airingTodaySeries?.incrementCurrentPage()
            Task {
                if let newPage = airingTodaySeries?.currentPage {
                    await getAiringTodaySeries(page: newPage)
                }
            }
        case .trendingSeries:
            trendingSeries?.incrementCurrentPage()
            Task {
                if let newPage = trendingSeries?.currentPage {
                    await getTrendingSeries(page: newPage)
                }
            }
        case .latestSeries:
            latestSeries?.incrementCurrentPage()
            Task {
                if let newPage = latestSeries?.currentPage {
                    await getLatestSeries(page: newPage)
                }
            }
        default:
            break
        }
    }
    
    func canLoadMoreContent(section: ViewSections) -> Bool {
        
        switch section {
        case .popularSeries:
            return popularSeries?.canLoadMoreContent() ?? false
        case .airingTodaySeries:
            return airingTodaySeries?.canLoadMoreContent() ?? false
        case .trendingSeries:
            return trendingSeries?.canLoadMoreContent() ?? false
        case .latestSeries:
            return latestSeries?.canLoadMoreContent() ?? false
        default:
            return false
        }
    }
    
    func getTrendingSeries(page: Int = 1) async {
        
        do {
            let fetchedSeries = try await service.fetchTrendingSeries(page: page)
            
            if page == 1 {
                self.trendingSeries = .init(result: fetchedSeries)
            } else {
                self.trendingSeries?.appendResult(fetchedSeries)
            }
        } catch {
            apiError = true
        }
    }
    
    func getPopularSeries(page: Int = 1) async {
        
        do {
            let fetchedSeries = try await service.fetchPopularSeries(page: page)
            
            if page == 1 {
                self.popularSeries = .init(result: fetchedSeries)
            } else {
                self.popularSeries?.appendResult(fetchedSeries)
            }
        } catch {
            apiError = true
        }
    }
    
    func getAiringTodaySeries(page: Int = 1) async {
        
        do {
            let fetchedSeries = try await service.fetchAiringTodaySeries(page: page)
            
            if page == 1 {
                self.airingTodaySeries = .init(result: fetchedSeries)
            } else {
                self.airingTodaySeries?.appendResult(fetchedSeries)
            }
        } catch {
            apiError = true
        }
    }
    
    func getLatestSeries(page: Int = 1) async {
        
        do {
            let fetchedSeries = try await service.fetchLatestSeries(page: page)
            
            if page == 1 {
                self.latestSeries = .init(result: fetchedSeries)
            } else {
                self.latestSeries?.appendResult(fetchedSeries)
            }
        } catch {
            apiError = true
        }
    }
}

extension SeriesViewModel {
    
    var popularSeries: ContentListResult? {
        get { model.popularSeries }
        set { model.popularSeries = newValue }
    }
    
    var airingTodaySeries: ContentListResult? {
        get { model.airingTodaySeries }
        set { model.airingTodaySeries = newValue }
    }
    
    var trendingSeries: ContentListResult? {
        get { model.trendingSeries }
        set { model.trendingSeries = newValue }
    }
    
    var latestSeries: ContentListResult? {
        get { model.latestSeries }
        set { model.latestSeries = newValue }
    }
    
    var featuredSerie: Result? {
        get { model.featuredSerie }
        set { model.featuredSerie = newValue }
    }
    
    var finishedLoadingContent: Bool {
        return true
//        return (popularSeries?.results.isEmpty == false &&
//                airingTodaySeries?.results.isEmpty == false &&
//                trendingSeries?.results.isEmpty == false &&
//                latestSeries?.results.isEmpty == false)
    }
}
