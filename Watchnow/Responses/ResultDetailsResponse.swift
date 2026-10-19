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
    let poster_path: String?
    let backdrop_path: String?
    let title: String?
    /// TV only — the most recently aired episode. What's New diffs its id
    /// to detect "a new episode is available".
    let last_episode_to_air: Episode?
    /// TV only — the next scheduled episode, if TMDB knows one.
    let next_episode_to_air: Episode?
    /// What `title` / `name` fall back to when TMDB has no translation in the
    /// requested language.
    var original_title: String? = nil
    var original_name: String? = nil
    /// Series only, and only when asked for (`append_to_response`). The
    /// About card reads the IMDb id from here for series; movies have
    /// `imdb_id` above.
    var external_ids: ExternalIDs? = nil
    /// Series: the age rating per country (`append_to_response`).
    var content_ratings: ContentRatings? = nil
    /// Films: release dates per country, which is where TMDB keeps their
    /// age ratings (`append_to_response`).
    var release_dates: ReleaseDates? = nil
    /// Series: typical episode lengths in minutes. Often empty on newer
    /// shows, which is why `typicalEpisodeMinutes` falls back.
    var episode_run_time: [Int]? = nil

    struct ExternalIDs: Codable, Hashable {
        let imdb_id: String?
    }

    struct ContentRatings: Codable, Hashable {
        let results: [Entry]?
        struct Entry: Codable, Hashable {
            let iso_3166_1: String?
            let rating: String?
        }
    }

    struct ReleaseDates: Codable, Hashable {
        let results: [Entry]?
        struct Entry: Codable, Hashable {
            let iso_3166_1: String?
            let release_dates: [Release]?
        }
        struct Release: Codable, Hashable {
            let certification: String?
            /// 1 premiere, 2 limited, 3 theatrical, 4 digital, 5 physical, 6 TV.
            let type: Int?
        }
    }

    /// The age rating in `region` — "TV-MA", "PG-13", "16" — or the US one
    /// when that country has none on file.
    func certification(region: String) -> String? {
        for code in [region, "US"] {
            if let rating = content_ratings?.results?
                .first(where: { $0.iso_3166_1 == code })?.rating,
               !rating.isEmpty {
                return rating
            }
            if let releases = release_dates?.results?.first(where: { $0.iso_3166_1 == code })?.release_dates {
                // The theatrical release's rating first; any other after.
                let rated = releases.filter { !($0.certification ?? "").isEmpty }
                if let rating = (rated.first(where: { $0.type == 3 }) ?? rated.first)?.certification {
                    return rating
                }
            }
        }
        return nil
    }

    /// How long an episode usually runs, in minutes.
    var typicalEpisodeMinutes: Int? {
        if let listed = episode_run_time?.first(where: { $0 > 0 }) { return listed }
        if let last = last_episode_to_air?.runtime, last > 0 { return last }
        return nil
    }

    /// The title's IMDb page, from whichever field this kind of title
    /// keeps its id in.
    var imdbURL: URL? {
        guard let id = imdb_id ?? external_ids?.imdb_id, !id.isEmpty else { return nil }
        return URL(string: "https://www.imdb.com/title/\(id)/")
    }

    func getSeasons() -> [Season]? {
        return seasons?.filter({ $0.season_number != 0 })
    }
    
    /// "2h 5m", abbreviated the way the app's language does it.
    func getRuntime() -> String? {
        guard let runtime, runtime > 0 else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: TimeInterval(runtime * 60))
    }
    
    func getBudget() -> String? {
        
        guard let budget = budget,
              budget != 0 else {
            return nil
        }
        
        // TMDB reports money in US dollars.
        return budget.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }
    
    func getRevenue() -> String? {
        
        guard let revenue = revenue,
              revenue != 0 else {
            return nil
        }
        
        return revenue.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }
    
    func getLanguages() -> [String]? {
        
        guard let spokenLanguages = spoken_languages else {
            return nil
        }
        
        var languages: [String]? = []
        
        // Named in the app's language, falling back to TMDB's English name.
        spokenLanguages.forEach { language in
            // Capitalised as a list item: French and Spanish name languages in
            // lower case ("anglais").
            let localized = language.iso_639_1
                .flatMap { Locale.current.localizedString(forLanguageCode: $0) }
                .map { $0.prefix(1).uppercased(with: .current) + $0.dropFirst() }
            languages?.append(localized ?? language.english_name ?? "")
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
        
        return tagline
    }
    
    /// The release date written out in the app's language: "10 October 2026",
    /// "10. Oktober 2026".
    func getDate() -> String? {
        guard let release_date, !release_date.isEmpty else { return nil }

        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: release_date) else { return nil }

        return date.formatted(date: .long, time: .omitted)
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
    /// TMDB's season score, 0–10. `0` means nobody has rated it yet — unaired
    /// seasons and Specials both come back that way.
    var vote_average: Double?

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
    var iso_639_1: String?
}

struct Collection: Codable, Hashable {
    
    var id: Int?
    var name: String?
    var backdrop_path: String?
    var poster_path: String?
    /// Set on `created_by` entries (people), nil on a film collection.
    var profile_path: String? = nil
}
