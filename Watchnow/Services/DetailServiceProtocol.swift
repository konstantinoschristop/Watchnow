//
//  DetailServiceProtocol.swift
//  Watchnow
//

import Foundation

protocol DetailServiceProtocol: AnyObject, Sendable {
    func fetchCredits(screenType: ScreenTypes, id: String) async throws -> ResultCreditsResponse
    func fetchSimilars(screenType: ScreenTypes, id: String) async throws -> GetSimilarModel
    func fetchReviews(screenType: ScreenTypes, id: String) async throws -> ResultReviewsResponse
    func fetchSearchResults(search: String) async throws -> SearchResponse
    func fetchVideos(screenType: ScreenTypes, id: String) async throws -> VideoResponse
    func fetchDetails(screenType: ScreenTypes, id: String) async throws -> ResultDetailsResponse
    func fetchEpisodes(seriesID: Int, seasonNumber: Int) async throws -> EpisodesResponse
    func fetchCollection(collectionID: Int) async throws -> CollectionResponse
    func fetchWatchProviders(screenType: ScreenTypes, id: String) async throws -> WatchProvidersResponse
}
