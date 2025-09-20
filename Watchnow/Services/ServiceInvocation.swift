//
//  ServiceInvaction.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 13/2/22.
//

import Foundation

class ServiceInvocation: BaseNetworkService {

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
        guard let query = search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw URLError(.badURL)
        }
        let urlString = API.Search.multi(query: query)
        return try await request(urlString: urlString)
    }

    func fetchVideos(screenType: ScreenTypes, id: String) async throws -> VideoResponse {
        let urlString = API.Common.videos(type: screenType.rawValue, for: id)
        return try await request(urlString: urlString)
    }

    func fetchDetails(screenType: ScreenTypes, id: String) async throws -> ResultDetailsReponse {
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

    func fetchCollection(collectionID: Int) async throws -> CollectionResponse {
        let urlString = API.Common.collection(id: collectionID)
        return try await request(urlString: urlString)
    }

    func fetchImages(screenType: ScreenTypes, id: String) async throws -> ImagesResponse {
        let urlString = API.Common.images(type: screenType.rawValue, for: id)
        return try await request(urlString: urlString)
    }

    func fetchWatchProviders(screenType: ScreenTypes, id: String) async throws -> WatchProvidersResponse {
        let urlString = API.Common.watchProviders(type: screenType.rawValue, id: id)
        return try await request(urlString: urlString)
    }
}
