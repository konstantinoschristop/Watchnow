//
//  VideoModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 30/7/22.
//

import Foundation

struct VideoResponse: Codable {
    var results: [VideoModelResult]?
    
    /// The title's trailer: an official one if there is one, then any
    /// trailer, then an official teaser, then any teaser — each in the device
    /// language when there's one, then in English, then whatever there is.
    /// The videos request asks for the device language, English and no
    /// language at all.
    ///
    /// TMDB calls a video official only when the studio uploaded it, and for
    /// older series that's often nothing — their trailers came from someone
    /// else. Taking official trailers alone left most of a streaming
    /// service's headline series with none. Clips, featurettes and opening
    /// credits aren't trailers, and still don't count.
    func getVideoURL() -> URL? {
        trailerKey.flatMap { URL(string: API.Common.youtubeUrl(videoId: $0)) }
    }

    /// The YouTube id of that trailer.
    var trailerKey: String? {
        let youtube = (results ?? []).filter { ($0.site ?? "YouTube") == "YouTube" && $0.key != nil }
        let tiers: [(type: String, officialOnly: Bool)] = [("Trailer", true), ("Trailer", false),
                                                            ("Teaser", true), ("Teaser", false)]
        for tier in tiers {
            let videos = youtube.filter { $0.type == tier.type && (!tier.officialOnly || $0.official == true) }
            if let video = videos.first(where: { $0.iso_639_1 == API.languageCode })
                ?? videos.first(where: { $0.iso_639_1 == "en" })
                ?? videos.first {
                return video.key
            }
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
