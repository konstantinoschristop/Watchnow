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
            self.trendingSeries = try await service.fetchTrendingSeries()
        } catch {
            print(error)
        }
    }
    
    func getPopularSeries() async {
        
        do {
            self.popularSeries = try await service.fetchPopularSeries()
        } catch {
            print(error)
        }
    }
    
    func getAiringTodaySeries() async {
        
        do {
            self.airingTodaySeries = try await service.fetchAiringTodaySeries()
        } catch {
            print(error)
        }
    }
}
