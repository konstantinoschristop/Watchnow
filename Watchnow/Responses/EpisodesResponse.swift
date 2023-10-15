//
//  EpisodesResponse.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 15/8/22.
//

import Foundation

struct EpisodesResponse: Codable {
    
    var episodes: [Episode]?
}

struct Episode: Codable, Hashable {
    
    let id: Int?
    let name: String?
    let overview: String?
    let still_path: String?
    let vote_average: Double?
    let vote_count: Int?
    let air_date: String?
    let episode_number: Int?
}
