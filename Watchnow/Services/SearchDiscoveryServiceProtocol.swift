//
//  SearchDiscoveryServiceProtocol.swift
//  Watchnow
//
//  Created by k.christopoulos on 31/8/26.
//

import Foundation

/// The browse-without-typing endpoints behind the search start screen:
/// the day's trending feeds, and TMDB Discover scoped to a single genre.
///
/// Deliberately *not* folded into `DetailServiceProtocol`: that protocol is
/// about a single title (credits, videos, reviews, …) and already carries
/// eleven methods. Search is the one place that needs both a detail
/// endpoint and browsable feeds, so it composes the two protocols at the
/// call site instead — either half stays mockable on its own.
protocol SearchDiscoveryServiceProtocol: AnyObject, Sendable {
    func fetchTrendingMovies(page: Int) async throws -> GenericResultResponse
    func fetchTrendingSeries(page: Int) async throws -> GenericResultResponse
    func fetchByGenre(screenType: ScreenTypes,
                      genreID: Int,
                      page: Int) async throws -> GenericResultResponse
}
