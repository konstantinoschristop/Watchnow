//
//  MoviesViewModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 30/7/22.
//

import Foundation

@MainActor
class MoviesViewModel: ObservableObject {
    
    @Published private(set) var upcomingMovies: UpcomingMoviesModel?
    @Published private(set) var popularMovies: PopularMoviesModel?
    @Published private(set) var trendingMovies: TrendingMoviesModel?
    
    private let service: MovieService = .init()
    
    func getTrendingMovies() async {
        
        do {
            self.trendingMovies = try await service.fetchTrendingMovies()
        } catch {
            print(error)
        }
    }
    
    func getUpcomingMovies() async {
        
        do {
            self.upcomingMovies = try await service.fetchUpcomingMovies()
        } catch {
            print(error)
        }
    }
    
    func getPopularMovies() async {
        
        do {
            self.popularMovies = try await service.fetchPopularMovies()
        } catch {
            print(error)
        }
    }
}




