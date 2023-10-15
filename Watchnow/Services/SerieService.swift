//
//  SerieService.swift
//  Watchnow
//
//  Created by k.christopoulos on 30/11/21.
//

import Foundation

class SerieService {
    
    let api = APIKeys()
    
    func fetchPopularSeries(page: Int) async throws -> GenericReultResponse {
        
        let url = URL(string: api.popularSeries + page.description)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(GenericReultResponse.self, from: data)
    }
    
    func fetchAiringTodaySeries(page: Int) async throws -> GenericReultResponse {
        
        let url = URL(string: api.airingTodaySeries + page.description)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(GenericReultResponse.self, from: data)
    }
    
    func fetchTrendingSeries(page: Int) async throws -> GenericReultResponse {
        
        let url = URL(string: api.trendingSeries + page.description)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(GenericReultResponse.self, from: data)
    }
    
    func fetchLatestSeries(page: Int) async throws -> GenericReultResponse {
        
        let url = URL(string: api.topRatedSeries + page.description)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(GenericReultResponse.self, from: data)
    }
}
