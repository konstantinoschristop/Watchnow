//
//  SerieService.swift
//  Watchnow
//
//  Created by k.christopoulos on 30/11/21.
//

import Foundation

final class SerieService: BaseNetworkService {

    func fetchPopularSeries(page: Int) async throws -> GenericReultResponse {
        return try await request(urlString: API.TV.popular(page: page))
    }

    func fetchAiringTodaySeries(page: Int) async throws -> GenericReultResponse {
        return try await request(urlString: API.TV.airingToday(page: page))
    }

    func fetchTrendingSeries(page: Int) async throws -> GenericReultResponse {
        return try await request(urlString: API.TV.trending(page: page))
    }

    func fetchLatestSeries(page: Int) async throws -> GenericReultResponse {
        return try await request(urlString: API.TV.topRated(page: page))
    }
}

extension SerieService: @unchecked Sendable {}
