//
//  ContentDetailsModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 12/8/22.
//

import Foundation

struct ContentDetailsModel: Codable {
    
    let genres: [Genres]?
    let seasons: [Season]?
    let number_of_episodes: Int?
    let number_of_seasons: Int?
    let name: String?
    let id: Int?
    
    func getSeasons() -> [Season]? {
        return seasons?.filter( { $0.season_number != 0 })
    }
}

struct Season: Codable, Hashable, Identifiable {
    
    var air_date: String?
    var episode_count: Int?
    var id: Int?
    var name: String?
    var overview: String?
    var poster_path: String?
    var season_number: Int?
    
    func getAirDate() -> String? {
        
        if let date = air_date?.dropLast(6) {
            return "(\(date))"
        }
        
        return nil
    }
}
