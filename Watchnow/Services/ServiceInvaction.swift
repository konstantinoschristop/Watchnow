//
//  ServiceInvaction.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 13/2/22.
//

import Foundation

class ServiceInvaction {
    
    let api = APIKeys()
    
    func fetchCredits(screenType: ScreenTypes, id: String) async throws -> CreditsModel {
        
        let url = URL(string: api.baseURL + screenType.rawValue + "/" + id + "/" + api.credits)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(CreditsModel.self, from: data)
    }
    
    func fetchSimilars(screenType: ScreenTypes, id: String) async throws -> GetSimilarModel {
        
        let url = URL(string: api.baseURL + screenType.rawValue + "/" + id + "/" + api.similar)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(GetSimilarModel.self, from: data)
    }
    
    func fetchReviews(screenType: ScreenTypes, id: String) async throws -> ReviewsModel {
        
        let url = URL(string: api.baseURL + screenType.rawValue + "/" + id + "/" + api.reviews)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(ReviewsModel.self, from: data)
    }
    
    func fetchSearchResults(search: String) async throws -> SearchModel {
        
        let query = search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        let url = URL(string: api.searchURL + query!)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(SearchModel.self, from: data)
    }
    
    func fetchVideos(screenType: ScreenTypes, id: String) async throws -> VideoModel {
        
        let url = URL(string: api.baseURL + screenType.rawValue + "/" + id + "/" + api.videos)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(VideoModel.self, from: data)
    }
    
    func fetchDetails(screenType: ScreenTypes, id: String) async throws -> ContentDetailsModel {
        
        let url = URL(string: api.baseURL + screenType.rawValue + "/" + id + api.apikey)
        
        let urlSession = URLSession.shared
        let (data,_) = try await urlSession.data(from: url!)
        return try JSONDecoder().decode(ContentDetailsModel.self, from: data)
    }
}
