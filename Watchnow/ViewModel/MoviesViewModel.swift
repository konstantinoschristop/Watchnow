//
//  MoviesViewModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 30/7/22.
//

import Foundation

@MainActor
class MoviesViewModel: ObservableObject {
    
    enum Sections {
        case upcomingMovies
        case popularMovies
        case trendingMovies
    }
    
    @Published private(set) var upcomingMovies: UpcomingMoviesModel?
    @Published private(set) var popularMovies: PopularMoviesModel?
    @Published private(set) var trendingMovies: TrendingMoviesModel?
    @Published var upcomingMoviesCurrentPage = 1
    private var popularMoviesCurrentPage = 1
    private var trendingMoviesCurrentPage = 1
    
    private let service: MovieService = .init()
    
    func shouldloadMoreContent(currentItem item: Result?, section: Sections) -> Bool {
        
        guard let item = item else {
            return false
        }
        
        var results: [Result]?
        
        switch section {
        case .upcomingMovies:
            results = upcomingMovies?.results
        case .popularMovies:
            results = popularMovies?.results
        case .trendingMovies:
            results = trendingMovies?.results
        }
        
        if let results = results {
            let thresholdIndex = results.index(results.endIndex, offsetBy: -5)
            if results.firstIndex(where: { $0.id == item.id }) == thresholdIndex {
                return true
            }
        }
        
        return false
    }
    
    func getTrendingMovies() async {
        
        do {
            self.trendingMovies = try await service.fetchTrendingMovies(page: 1)
            self.trendingMovies?.results.append(contentsOf: try await service.fetchTrendingMovies(page: 2).results)
        } catch {
            print(error)
        }
    }
    
    func getUpcomingMovies() async {
        
        do {
            self.upcomingMovies = try await service.fetchUpcomingMovies(page: 1)
            self.upcomingMovies?.results.append(contentsOf: try await service.fetchUpcomingMovies(page: 2).results)
        } catch {
            print(error)
        }
    }
    
    func getPopularMovies(page: Int = 1) async {
        
        do {
            self.popularMovies = try await service.fetchPopularMovies(page: 1)
            self.popularMovies?.results.append(contentsOf: try await service.fetchPopularMovies(page: 2).results)
        } catch {
            print(error)
        }
    }
}




