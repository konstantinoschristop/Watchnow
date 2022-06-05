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
}
