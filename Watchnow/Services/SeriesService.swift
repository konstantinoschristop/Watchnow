//
//  SeriesService.swift
//  Watchnow
//
//  Created by k.christopoulos on 30/11/21.
//

import Foundation

final class SeriesService: BaseNetworkService {

    func fetchPopularSeries(page: Int) async throws -> GenericResultResponse {
        return try await request(urlString: API.TV.popular(page: page))
    }

    func fetchAiringTodaySeries(page: Int) async throws -> GenericResultResponse {
        return try await request(urlString: API.TV.airingToday(page: page))
    }

    func fetchTrendingSeries(page: Int) async throws -> GenericResultResponse {
        return try await request(urlString: API.TV.trending(page: page))
    }

    func fetchLatestSeries(page: Int) async throws -> GenericResultResponse {
        return try await request(urlString: API.TV.topRated(page: page))
    }

    /// Same endpoint as `fetchLatestSeries` because TMDB's TV API doesn't
    /// expose a separate "newest releases" stream — `top_rated` is the
    /// only TV endpoint that returns curated quality picks. The series
    /// tab currently doesn't use both (Top 10 supersedes Critics' Choice
    /// in the section list), so the duplicate is logical, not actual.
    func fetchTopRatedSeries(page: Int) async throws -> GenericResultResponse {
        return try await request(urlString: API.TV.topRated(page: page))
    }
}

extension SeriesService: @unchecked Sendable {}
