//
//  TrendingServiceProtocol.swift
//  Watchnow
//
//  Created by k.christopoulos on 31/8/26.
//

import Foundation

/// Day-level trending feeds.
///
/// Deliberately *not* folded into `DetailServiceProtocol`: that protocol is
/// about a single title (credits, videos, reviews, …) and already carries
/// eleven methods. The search start screen is the one place that needs both
/// a detail endpoint and a browsable feed, so it composes the two protocols
/// at the call site instead — either half stays mockable on its own.
protocol TrendingServiceProtocol: AnyObject, Sendable {
    func fetchTrendingMovies(page: Int) async throws -> GenericResultResponse
    func fetchTrendingSeries(page: Int) async throws -> GenericResultResponse
}
