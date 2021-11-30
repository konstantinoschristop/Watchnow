//
//  SerieService.swift
//  Watchnow
//
//  Created by k.christopoulos on 30/11/21.
//

import Foundation

class SerieService {
    
    let api = APIKeys()
    
    func fetchPopularSeries() async throws -> PopularSeriesModel {
        
        let url = URL(string: api.popularSeries)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(PopularSeriesModel.self, from: data)
    }
    
    func fetchAiringTodaySeries() async throws -> AiringTodaySeriesModel {
        
        let url = URL(string: api.airingTodaySeries)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(AiringTodaySeriesModel.self, from: data)
    }
    
    func fetchTrendingSeries() async throws -> TrendingSeriesModel {
        
        let url = URL(string: api.trendingSeries)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(TrendingSeriesModel.self, from: data)
    }
}
