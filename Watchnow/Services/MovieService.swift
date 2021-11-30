//
//  MovieService.swift
//  Watchnow
//
//  Created by k.christopoulos on 27/11/21.
//

import Foundation

class MovieService {
    
    let api = APIKeys()
    
    func fetchUpcomingMovies() async throws -> UpcomingMoviesModel {
        
        let url = URL(string: api.upcomingMovies)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(UpcomingMoviesModel.self, from: data)
    }
    
    func fetchPopularMovies() async throws -> PopularMoviesModel {
        
        let url = URL(string: api.popularMovies)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(PopularMoviesModel.self, from: data)
    }
    
    func fetchTrendingMovies() async throws -> TrendingMoviesModel {
        
        let url = URL(string: api.trendingMovies)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(TrendingMoviesModel.self, from: data)
    }
}
