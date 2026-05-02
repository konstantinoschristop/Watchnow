//
//  ServiceInvaction.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 13/2/22.
//

import Foundation

final class ServiceInvocation: BaseNetworkService, DetailServiceProtocol {

    func fetchCredits(screenType: ScreenTypes, id: String) async throws -> ResultCreditsResponse {
        let urlString = API.Common.credits(type: screenType.rawValue, for: id)
        return try await request(urlString: urlString)
    }

    func fetchSimilars(screenType: ScreenTypes, id: String) async throws -> GetSimilarModel {
        let urlString = API.Common.similar(type: screenType.rawValue, for: id)
        return try await request(urlString: urlString)
    }

    func fetchReviews(screenType: ScreenTypes, id: String) async throws -> ResultReviewsResponse {
        let urlString = API.Common.reviews(type: screenType.rawValue, for: id)
        return try await request(urlString: urlString)
    }

    func fetchSearchResults(search: String) async throws -> SearchResponse {
        let urlString = API.Search.multi(query: search)
        return try await request(urlString: urlString)
    }

    func fetchVideos(screenType: ScreenTypes, id: String) async throws -> VideoResponse {
        let urlString = API.Common.videos(type: screenType.rawValue, for: id)
        return try await request(urlString: urlString)
    }

    func fetchDetails(screenType: ScreenTypes, id: String) async throws -> ResultDetailsResponse {
        let urlString = API.Common.details(screenType: screenType.rawValue, id: id)
        return try await request(urlString: urlString)
    }

    func fetchEpisodes(seriesID: Int, seasonNumber: Int) async throws -> EpisodesResponse {
        let urlString = API.Common.season(tvId: seriesID, seasonNumber: seasonNumber)
        return try await request(urlString: urlString)
    }

    func fetchPerson(personID: Int) async throws -> PersonResponse {
        let urlString = API.Common.person(id: personID)
        return try await request(urlString: urlString)
    }

    /// Returns every movie / TV credit a person has — used by the actor
    /// sheet's "Known For" section when the caller didn't already have a
    /// pre-loaded `known_for` array (e.g. tapped from a cast carousel
    /// rather than a multi-search result). The cast and crew arrays both
    /// reuse the existing `Result` shape because TMDB's combined_credits
    /// response uses the same field set as the search/discover endpoints.
    func fetchCombinedCredits(personID: Int) async throws -> PersonCombinedCreditsResponse {
        let urlString = API.Common.personCombinedCredits(id: personID)
        return try await request(urlString: urlString)
    }

    func fetchCollection(collectionID: Int) async throws -> CollectionResponse {
        let urlString = API.Common.collection(id: collectionID)
        return try await request(urlString: urlString)
    }

    func fetchWatchProviders(screenType: ScreenTypes, id: String) async throws -> WatchProvidersResponse {
        let urlString = API.Common.watchProviders(type: screenType.rawValue, id: id)
        return try await request(urlString: urlString)
    }
}

