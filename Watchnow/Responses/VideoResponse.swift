//
//  VideoModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 30/7/22.
//

import Foundation

struct VideoResponse: Codable {
    var results: [VideoModelResult]?
    
    func getVideoURL() -> URL? {
        
        if let key = results?.first(where: { $0.official == true && $0.type == "Trailer" })?.key {
            return URL(string: APIKeys.youtubeBaseURL + key)
        }
        
        return nil
    }
}

struct VideoModelResult: Codable {
    var key: String?
    var official: Bool?
    var type: String?
}
