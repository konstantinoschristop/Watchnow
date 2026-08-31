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
            return URL(string: API.Common.youtubeUrl(videoId: key))
        }
        
        return nil
    }
}

struct VideoModelResult: Codable {
    /// TMDB's stable video id — what the What's New snapshot diff keys on.
    var id: String?
    var key: String?
    var name: String?
    var site: String?
    var official: Bool?
    var type: String?
}
