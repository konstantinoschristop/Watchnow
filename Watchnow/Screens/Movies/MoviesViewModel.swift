//
//  MoviesViewModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 30/7/22.
//

import Foundation

@MainActor
protocol BaseViewModelProtocol {
    
    func loadMoreContent(section: ViewSections)
    func canLoadMoreContent(section: ViewSections) -> Bool
}

@MainActor
class MoviesViewModel: ObservableObject, BaseViewModelProtocol {
    
    @Published var model: MoviesModel
    @Published var apiError: Bool = false
    private let service: MovieService
    
    init(model: MoviesModel, 
         service: MovieService = MovieService()) {
        
        self.model = model
        self.service = service
    }
    
    func loadMoreContent(section: ViewSections) {
        
        guard canLoadMoreContent(section: section) else {
            return
        }
        
        switch section {
        case .upcomingMovies:
            upcomingMoviesCurrentPage += 1
        case .popularMovies:
            popularMoviesCurrentPage += 1
        case .trendingMovies:
           trendingMoviesCurrentPage += 1
        case .latestMovies:
            latestMoviesCurrentPage += 1
        default:
            break
        }
    }
    
    func canLoadMoreContent(section: ViewSections) -> Bool {
        
        switch section {
        case .upcomingMovies:
            guard let totalPages = upcomingMovies?.total_pages else {
                return false
            }
            return upcomingMoviesCurrentPage < totalPages
        case .popularMovies:
            guard let totalPages = popularMovies?.total_pages else {
                return false
            }
            return popularMoviesCurrentPage < totalPages
        case .trendingMovies:
            guard let totalPages = trendingMovies?.total_pages else {
                return false
            }
            return trendingMoviesCurrentPage < totalPages
        case .latestMovies:
            guard let totalPages = latestMovies?.total_pages else {
                return false
            }
            return latestMoviesCurrentPage < totalPages
        default:
            return false
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
    
    func getLatestMovieResults() -> [Result]? {
        return self.latestMovies?.results
    }
    
    func getTrendingMovies(page: Int = 1) async {
        
        do {
            if page == 1 {
                self.trendingMovies = try await service.fetchTrendingMovies(page: page)
            } else {
                self.trendingMovies?.results.append(contentsOf: try await service.fetchTrendingMovies(page: page).results)
            }
        } catch {
            apiError = true
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
            apiError = true
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
            apiError = true
        }
    }
    
    func getLatestMovies(page: Int = 1) async {
        
        do {
            if page == 1 {
                self.latestMovies = try await service.fetchLatestMovies(page: page)
            } else {
                self.latestMovies?.results.append(contentsOf: try await service.fetchLatestMovies(page: page).results)
            }
        } catch {
            apiError = true
        }
    }
}

extension MoviesViewModel {
    
    var upcomingMovies: GenericReultResponse? {
        get { model.upcomingMovies }
        set { model.upcomingMovies = newValue }
    }
    
    var popularMovies: GenericReultResponse? {
        get { model.popularMovies }
        set { model.popularMovies = newValue }
    }
    
    var trendingMovies: GenericReultResponse? {
        get { model.trendingMovies }
        set { model.trendingMovies = newValue }
    }
    
    var latestMovies: GenericReultResponse? {
        get { model.latestMovies }
        set { model.latestMovies = newValue }
    }
    
    var upcomingMoviesCurrentPage: Int {
        get { model.upcomingMoviesCurrentPage }
        set { model.upcomingMoviesCurrentPage = newValue }
    }
    
    var popularMoviesCurrentPage: Int {
        get { model.popularMoviesCurrentPage }
        set { model.popularMoviesCurrentPage = newValue }
    }
    
    var trendingMoviesCurrentPage: Int {
        get { model.trendingMoviesCurrentPage }
        set { model.trendingMoviesCurrentPage = newValue }
    }
    
    var latestMoviesCurrentPage: Int {
        get { model.latestMoviesCurrentPage }
        set { model.latestMoviesCurrentPage = newValue }
    }
    
    var featuredMovie: Result? {
        get { model.featuredMovie }
    }
    
    var finishedLoadingContent: Bool {
        return (upcomingMovies?.results.isEmpty == false &&
                popularMovies?.results.isEmpty == false &&
                trendingMovies?.results.isEmpty == false &&
                latestMovies?.results.isEmpty == false)
    }
}
