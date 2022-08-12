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
    @Published private var popularMovies: PopularMoviesModel?
    @Published private var trendingMovies: TrendingMoviesModel?
    @Published private(set) var upcomingMoviesCurrentPage = 1
    @Published private(set) var popularMoviesCurrentPage = 1
    @Published private(set) var trendingMoviesCurrentPage = 1
    
    private let service: MovieService = .init()
    
    func loadMoreContent(section: ViewSections) {
        
        switch section {
        case .upcomingMovies:
            if upcomingMoviesCurrentPage < 20 {
                upcomingMoviesCurrentPage += 1
            }
        case .popularMovies:
            if popularMoviesCurrentPage < 20 {
                popularMoviesCurrentPage += 1
            }
        case .trendingMovies:
            if trendingMoviesCurrentPage < 20 {
                trendingMoviesCurrentPage += 1
            }
        default:
            break
        }
    }
    
    func getUpcomingMovieResults() -> [Result]? {
        return self.upcomingMovies?.results
    }
    
    func getPopularMovieResults() -> [Result]? {
        return self.popularMovies?.results
    }
    
    func getTrendingMovieResults() -> [Result]? {
        return self.trendingMovies?.results
    }
    
    func getTrendingMovies(page: Int = 1) async {
        
        do {
            if page == 1 {
                self.trendingMovies = try await service.fetchTrendingMovies(page: page)
            } else {
                self.trendingMovies?.results.append(contentsOf: try await service.fetchTrendingMovies(page: page).results)
            }
        } catch {
            print(error)
        }
    }
    
    func getUpcomingMovies(page: Int = 1) async {
        
        do {
            if page == 1 {
                self.upcomingMovies = try await service.fetchUpcomingMovies(page: page)
            } else {
                self.upcomingMovies?.results.append(contentsOf: try await service.fetchUpcomingMovies(page: page).results)
            }
        } catch {
            print(error)
        }
    }
    
    func getPopularMovies(page: Int = 1) async {
        
        do {
            if page == 1 {
                self.popularMovies = try await service.fetchPopularMovies(page: page)
            } else {
                self.popularMovies?.results.append(contentsOf: try await service.fetchPopularMovies(page: page).results)
            }
        } catch {
            print(error)
        }
    }
}




