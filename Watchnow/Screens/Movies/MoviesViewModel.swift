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
    
    func loadContent() async {
        await getTrendingMovies()
        await getLatestMovies()
        await getPopularMovies()
        await getUpcomingMovies()
    }
    
    func loadMoreContent(section: ViewSections) {
        
        guard canLoadMoreContent(section: section) else {
            return
        }
        
        switch section {
        case .upcomingMovies:
            upcomingMovies?.incrementCurrentPage()
            Task {
                if let newPage = upcomingMovies?.currentPage {
                    await getUpcomingMovies(page: newPage)
                }
            }
        case .popularMovies:
            popularMovies?.incrementCurrentPage()
            Task {
                if let newPage = popularMovies?.currentPage {
                    await getPopularMovies(page: newPage)
                }
            }
        case .trendingMovies:
            trendingMovies?.incrementCurrentPage()
            Task {
                if let newPage = trendingMovies?.currentPage {
                    await getTrendingMovies(page: newPage)
                }
            }
        case .latestMovies:
            latestMovies?.incrementCurrentPage()
            Task {
                if let newPage = latestMovies?.currentPage {
                    await getLatestMovies(page: newPage)
                }
            }
        default:
            break
        }
    }
    
    func canLoadMoreContent(section: ViewSections) -> Bool {
        
        switch section {
        case .upcomingMovies:
            return upcomingMovies?.canLoadMoreContent() ?? false
        case .popularMovies:
            return popularMovies?.canLoadMoreContent() ?? false
        case .trendingMovies:
            return trendingMovies?.canLoadMoreContent() ?? false
        case .latestMovies:
            return latestMovies?.canLoadMoreContent() ?? false
        default:
            return false
        }
    }
    
    func getUpcomingMovieResults() -> [Result]? {
        return self.upcomingMovies?.getResults()
    }
    
    func getPopularMovieResults() -> [Result]? {
        return self.popularMovies?.getResults()
    }
    
    func getTrendingMovieResults() -> [Result]? {
        return self.trendingMovies?.getResults()
    }
    
    func getLatestMovieResults() -> [Result]? {
        return self.latestMovies?.getResults()
    }
    
    func getTrendingMovies(page: Int = 1) async {
        
        do {
            let fetchedMovies = try await service.fetchTrendingMovies(page: page)
            
            if page == 1 {
                self.trendingMovies = .init(result: fetchedMovies)
            } else {
                self.trendingMovies?.appendResult(fetchedMovies)
            }
        } catch {
            apiError = true
        }
    }
    
    func getUpcomingMovies(page: Int = 1) async {
        
        do {
            let fetchedMovies = try await service.fetchUpcomingMovies(page: page)
            
            if page == 1 {
                self.upcomingMovies = .init(result: fetchedMovies)
            } else {
                self.upcomingMovies?.appendResult(fetchedMovies)
            }
        } catch {
            apiError = true
        }
    }
    
    func getPopularMovies(page: Int = 1) async {
        
        do {
            let fetchedMovies = try await service.fetchPopularMovies(page: page)
            
            if page == 1 {
                self.popularMovies = .init(result: fetchedMovies)
            } else {
                self.popularMovies?.appendResult(fetchedMovies)
            }
        } catch {
            apiError = true
        }
    }
    
    func getLatestMovies(page: Int = 1) async {
        
        do {
            let fetchedMovies = try await service.fetchLatestMovies(page: page)
            
            if page == 1 {
                self.latestMovies = .init(result: fetchedMovies)
            } else {
                self.latestMovies?.appendResult(fetchedMovies)
            }
        } catch {
            apiError = true
        }
    }
}

extension MoviesViewModel {
    
    var upcomingMovies: ContentListResult? {
        get { model.upcomingMovies }
        set { model.upcomingMovies = newValue }
    }
    
    var popularMovies: ContentListResult? {
        get { model.popularMovies }
        set { model.popularMovies = newValue }
    }
    
    var trendingMovies: ContentListResult? {
        get { model.trendingMovies }
        set { model.trendingMovies = newValue }
    }
    
    var latestMovies: ContentListResult? {
        get { model.latestMovies }
        set { model.latestMovies = newValue }
    }
    
    var featuredMovie: Result? {
        get { model.featuredMovie }
    }
    
    var finishedLoadingContent: Bool {
        return true
//        return (upcomingMovies?.results.isEmpty == false &&
//             //   popularMovies?.results.isEmpty == false &&
//                trendingMovies?.results.isEmpty == false &&
//                latestMovies?.results.isEmpty == false)
    }
}
