//
//  ServiceInvaction.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 13/2/22.
//

import Foundation

enum ResponseDumper {
    
    static func printJSON(for url: URL?, and data: Data) {
        print("------ RESPONSE ------")
        print(String(describing: url))
        print(String(data: data, encoding: .utf8) as Any)
    }
}

class ServiceInvocation {
    
    let api = APIKeys()
    
    func fetchCredits(screenType: ScreenTypes, id: String) async throws -> ResultCreditsResponse {
        
        let url = URL(string: api.baseURL + screenType.rawValue + "/" + id + "/" + api.credits)
        
        let urlSession = URLSession.shared
        let (data,response) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(ResultCreditsResponse.self, from: data)
    }
    
    func fetchSimilars(screenType: ScreenTypes, id: String) async throws -> GetSimilarModel {
        
        let url = URL(string: api.baseURL + screenType.rawValue + "/" + id + "/" + api.similar)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        let response = try JSONDecoder().decode(GetSimilarModel.self, from: data)
        return response
    }
    
    func fetchReviews(screenType: ScreenTypes, id: String) async throws -> ResultReviewsResponse {
        
        let url = URL(string: api.baseURL + screenType.rawValue + "/" + id + "/" + api.reviews)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(ResultReviewsResponse.self, from: data)
    }
    
    func fetchSearchResults(search: String) async throws -> SearchResponse {
        
        let query = search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        let url = URL(string: api.searchURL + query!)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(SearchResponse.self, from: data)
    }
    
    func fetchVideos(screenType: ScreenTypes, id: String) async throws -> VideoResponse {
        
        let url = URL(string: api.baseURL + screenType.rawValue + "/" + id + api.videos)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(VideoResponse.self, from: data)
    }
    
    func fetchDetails(screenType: ScreenTypes, id: String) async throws -> ResultDetailsReponse {
        
        let url = URL(string: api.baseURL + screenType.rawValue + "/" + id + api.apikey)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        // ResponseDumper.printJSON(for: url, and: data)
        let response = try JSONDecoder().decode(ResultDetailsReponse.self, from: data)
        return response
    }
    
    func fetchEpisodes(seriesID: Int, seasonNumber: Int) async throws -> EpisodesResponse {
        
        let url = URL(string: api.baseURL + "tv/" + String(seriesID) + "/season/" + String(seasonNumber) + api.apikey)
        
        let urlSession = URLSession.shared
        let (data,response) = try await urlSession.data(from: url!)
        ResponseDumper.printJSON(for: url, and: data)
        return try JSONDecoder().decode(EpisodesResponse.self, from: data)
    }
    
    func fetchPerson(personID: Int)  async throws -> PersonResponse {
        
        let url = URL(string: api.baseURL + "person/" + String(personID) + api.apikey)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(PersonResponse.self, from: data)
    }
    
    func fetchCollection(collectionID: Int)  async throws -> CollectionResponse {
        
        let url = URL(string: api.baseURL + "collection/" + String(collectionID) + api.apikey)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(CollectionResponse.self, from: data)
    }
    
    func fetchImages(screenType: ScreenTypes, id: String)  async throws -> ImagesResponse {
        
        let url = URL(string: api.baseURL + screenType.rawValue + "/" + id + api.images)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(ImagesResponse.self, from: data)
    }
    
    func fetchWatchProviders(screenType: ScreenTypes, id: String) async throws -> WatchProvidersResponse {
        
        let url = URL(string: api.baseURL + screenType.rawValue + "/" + id + "/watch/providers" + api.apikey)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(WatchProvidersResponse.self, from: data)
    }
}
