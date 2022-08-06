//
//  SeriesViewModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 30/7/22.
//

import Foundation

@MainActor
class SeriesViewModel: ObservableObject {
    
    @Published private(set) var popularSeries: PopularSeriesModel?
    @Published private(set) var airingTodaySeries: AiringTodaySeriesModel?
    @Published private(set) var trendingSeries: TrendingSeriesModel?
    
    private let service: SerieService = .init()
    
    func getTrendingSeries() async {
        
        do {
            self.trendingSeries = try await service.fetchTrendingSeries(page: 1)
            self.trendingSeries?.results.append(contentsOf: try await service.fetchTrendingSeries(page: 2).results)
        } catch {
            print(error)
        }
    }
    
    func getPopularSeries() async {
        
        do {
            self.popularSeries = try await service.fetchPopularSeries(page: 1)
            self.popularSeries?.results.append(contentsOf: try await service.fetchPopularSeries(page: 2).results)
        } catch {
            print(error)
        }
    }
    
    func getAiringTodaySeries() async {
        
        do {
            self.airingTodaySeries = try await service.fetchAiringTodaySeries(page: 1)
            self.airingTodaySeries?.results.append(contentsOf: try await service.fetchAiringTodaySeries(page: 2).results)
        } catch {
            print(error)
        }
    }
}
