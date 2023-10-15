//
//  UpcomingMoviesModel.swift
//  Watchnow
//
//  Created by k.christopoulos on 1/8/21.
//

import Foundation

enum ViewSections {
    case upcomingMovies
    case popularMovies
    case trendingMovies
    case latestMovies
    
    case popularSeries
    case airingTodaySeries
    case trendingSeries
    case latestSeries
}

struct GenericReultResponse: Codable {
    var results: [Result]
    var total_pages: Int?
}

// MARK: - Result
struct Result: Codable, Hashable, Equatable {
    let backdrop_path: String?
    let first_air_date: String?
    let genre_ids: [Int]?
    let id: Int?
    let original_title: String?
    let name: String?
    let origin_country: [String]?
    let original_language, original_name, overview: String?
    let popularity: Double?
    let poster_path: String?
    let release_date: String?
    let title: String?
    let video: Bool?
    let vote_average: Double?
    let vote_count: Int?
    var media_type: String?
    let profile_path: String?
    let castID: Int?
    let runtime: Int?
    
    static func == (lhs: Result, rhs: Result) -> Bool {
        return lhs.id == rhs.id
    }
    
    func getResultTitle() -> String {
        return (name ?? title) ?? "- -"
    }
    
    func getResultPosterURL() -> String {
        return (poster_path ?? backdrop_path ?? profile_path) ?? ""
    }
    
    func getMediaType() -> String {
        if media_type == "movie" {
            return "Movie"
        } else if media_type == "tv" {
            return "TV Serie"
        } else {
            return "Actor"
        }
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
