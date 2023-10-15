//
//  MovieService.swift
//  Watchnow
//
//  Created by k.christopoulos on 27/11/21.
//

import Foundation

class MovieService {
    
    let api = APIKeys()
    
    func fetchUpcomingMovies(page: Int) async throws -> GenericReultResponse {
        
        let url = URL(string: api.upcomingMovies + page.description)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(GenericReultResponse.self, from: data)
    }
    
    func fetchPopularMovies(page: Int) async throws -> GenericReultResponse {
        
        let url = URL(string: api.popularMovies + page.description)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(GenericReultResponse.self, from: data)
    }
    
    func fetchTrendingMovies(page: Int) async throws -> GenericReultResponse {
        
        let url = URL(string: api.trendingMovies + page.description)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(GenericReultResponse.self, from: data)
    }
    
    func fetchLatestMovies(page: Int) async throws -> GenericReultResponse {
        
        let url = URL(string: api.nowPlayingMovies + page.description)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(GenericReultResponse.self, from: data)
    }
}
