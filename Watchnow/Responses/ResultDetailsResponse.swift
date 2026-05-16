//
//  ResultDetailsResponse.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 12/8/22.
//

import Foundation

struct ResultDetailsResponse: Codable {
    
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
    let release_date: String?
    let first_air_date: String?
    let overview: String?
    let vote_average: Double?
    let vote_count: Int?
    
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
    
    func getDate() -> String? {
        
        guard let release_date = release_date,
              release_date.isEmpty == false else {
            return nil
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        guard let date = formatter.date(from: release_date) else {
            return nil
        }
        
        formatter.dateFormat = "yyyy"
        let year = formatter.string(from: date)
        formatter.dateFormat = "MM"
        let month = monthFromDate(aDate: date)
        formatter.dateFormat = "dd"
        let day = formatter.string(from: date)
        
        return "\(day) \(month) \(year)"
    }
    
    private func monthFromDate(aDate: Date) -> String {
        
        var myCurrentCalendar = Calendar(identifier: .gregorian)
        myCurrentCalendar.locale = Locale(identifier: "en_GB")
        let currentComponents = myCurrentCalendar.dateComponents([.day, .month, .year], from: aDate)
        let monthSymbols = myCurrentCalendar.monthSymbols
        if let theMonth = currentComponents.month {
            return monthSymbols[theMonth - 1 ]
        }
        return ""
    }
    
    func getReleaseDate(addSeparator: Bool = true) -> String {
        
        if let date = release_date?.dropLast(6) {
            return date + (addSeparator ? " - " : "")
        } else if let date = first_air_date?.dropLast(6) {
            return date + (addSeparator ? " - " : "")
        } else {
            return ""
        }
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

    /// Parses `air_date` (yyyy-MM-dd) into a `Date`. Returns nil if the
    /// field is missing or unparseable.
    func airDateValue() -> Date? {
        guard let raw = air_date, !raw.isEmpty else { return nil }
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .iso8601)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.date(from: raw)
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
