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
    let imdb_id: String?
    let tagline: String?
    let spoken_languages: [Language]?
    let revenue: Double?
    let budget: Double?
    let runtime: Int?
    let belongs_to_collection: Collection?
    let status:  String?
    let homepage: String?
    let created_by: [Collection]?
    
    func getSeasons() -> [Season]? {
        return seasons?.filter({ $0.season_number != 0 })
    }
    
    func getRuntime() -> String? {
        
        guard let runtime = runtime else {
            return nil
        }

        let hours = String(runtime / 60)
        let minutes = String(runtime % 60)
        let runtimeString = String(hours + "h " + minutes + "m")
        
        return runtimeString
    }
    
    func getBudget() -> String? {
        
        guard let budget = budget,
              budget != 0 else {
            return nil
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current

        if let formattedString = formatter.string(for: budget) {
            return "$" + formattedString
        }
        
        return nil
    }
    
    func getRevenue() -> String? {
        
        guard let revenue = revenue,
              revenue != 0 else {
            return nil
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current

        if let formattedString = formatter.string(for: revenue) {
            return "$" + formattedString
        }
        
        return nil
    }
    
    func getLanguages() -> [String]? {
        
        guard let spokenLanguages = spoken_languages else {
            return nil
        }

        var languages: [String]? = []
        
        spokenLanguages.forEach { language in
            languages?.append(language.english_name ?? "")
        }
        
        return languages
    }
    
    func getCreatedBy() -> [String]? {
        
        guard let createdBy = created_by,
              createdBy.isEmpty == false else {
            return nil
        }

        var createdByArray: [String]? = []
        
        createdBy.forEach { createdBy in
            createdByArray?.append(createdBy.name ?? "")
        }
        
        return createdByArray
    }
    
    func getTagline() -> String? {
        
        guard let tagline = tagline,
              tagline.isEmpty == false else {
            return nil
        }

        return "'" + tagline + "'" 
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

struct Language: Codable, Hashable {
    
    var english_name: String?
}

struct Collection: Codable, Hashable {
    
    var id: Int?
    var name: String?
    var backdrop_path: String?
    var poster_path: String?
}
