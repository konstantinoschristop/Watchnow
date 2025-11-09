//
//  MovieService.swift
//  Watchnow
//
//  Created by k.christopoulos on 27/11/21.
//  Refactored for Swift 6 (2025)
//

import Foundation

// Keep the same return types to align with existing models.
// If GenericReultResponse is a typo in your models, we can fix it later across the project.
final class MovieService: BaseNetworkService {

    // MARK: - Public API

    func fetchUpcomingMovies(page: Int) async throws -> GenericReultResponse {
        try await request(urlString: API.Movie.upcoming(page: page))
    }

    func fetchPopularMovies(page: Int) async throws -> GenericReultResponse {
        try await request(urlString: API.Movie.popular(page: page))
    }

    func fetchTrendingMovies(page: Int) async throws -> GenericReultResponse {
        try await request(urlString: API.Movie.trending(page: page))
    }

    func fetchLatestMovies(page: Int) async throws -> GenericReultResponse {
        try await request(urlString: API.Movie.nowPlaying(page: page))
    }
}

extension MovieService: @unchecked Sendable {}
