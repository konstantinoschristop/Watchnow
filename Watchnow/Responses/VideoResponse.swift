//
//  VideoModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 30/7/22.
//

import Foundation

struct VideoResponse: Codable {
    var results: [VideoModelResult]?
    
    /// The official trailer: in the device language when there is one, then
    /// in English, then whatever there is. The videos request asks for the
    /// device language, English and no language at all.
    func getVideoURL() -> URL? {
        let trailers = results?.filter { $0.official == true && $0.type == "Trailer" } ?? []
        let trailer = trailers.first { $0.iso_639_1 == API.languageCode }
            ?? trailers.first { $0.iso_639_1 == "en" }
            ?? trailers.first

        if let key = trailer?.key {
            return URL(string: API.Common.youtubeUrl(videoId: key))
        }

        return nil
    }
}

struct VideoModelResult: Codable {
    /// TMDB's stable video id — what the What's New snapshot diff keys on.
    var id: String?
    /// The video's language, e.g. `el`. Nil for ones with no dialogue.
    var iso_639_1: String?
    var key: String?
    var name: String?
    var site: String?
    var official: Bool?
    var type: String?
}
