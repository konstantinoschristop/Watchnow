//
//  MoviesViewModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 30/7/22.
//

import Foundation

@MainActor
class MoviesViewModel: BaseContentViewModel {
    
    @Published var model: MoviesModel
    
    init(model: MoviesModel,
         service: MovieService = MovieService()) {
        
        self.model = model
        super.init(service: service)
    }
}

extension MovieService: ContentService {
    func fetchTrending(page: Int) async throws -> GenericReultResponse {
        try await fetchTrendingMovies(page: page)
    }
    
    func fetchPopular(page: Int) async throws -> GenericReultResponse {
        try await fetchPopularMovies(page: page)
    }
    
    func fetchUpcomingOrAiring(page: Int) async throws -> GenericReultResponse {
        try await fetchUpcomingMovies(page: page)
    }
    
    func fetchLatest(page: Int) async throws -> GenericReultResponse {
        try await fetchLatestMovies(page: page)
    }
}
