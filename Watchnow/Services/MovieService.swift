//
//  MovieService.swift
//  Watchnow
//
//  Created by k.christopoulos on 27/11/21.
//

import Foundation

class MovieService {
    
    let api = APIKeys()
    
    func fetchUpcomingMovies(page: Int) async throws -> UpcomingMoviesModel {
        
        let url = URL(string: api.upcomingMovies + page.description)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(UpcomingMoviesModel.self, from: data)
    }
    
    func fetchPopularMovies(page: Int) async throws -> PopularMoviesModel {
        
        let url = URL(string: api.popularMovies + page.description)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(PopularMoviesModel.self, from: data)
    }
    
    func fetchTrendingMovies(page: Int) async throws -> TrendingMoviesModel {
        
        let url = URL(string: api.trendingMovies + page.description)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(TrendingMoviesModel.self, from: data)
    }
}
