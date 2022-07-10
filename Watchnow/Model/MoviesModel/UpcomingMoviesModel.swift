//
//  UpcomingMoviesModel.swift
//  Watchnow
//
//  Created by k.christopoulos on 1/8/21.
//

import Foundation

struct UpcomingMoviesModel: Codable {
    let results: [Result]
}


// MARK: - Result
struct Result: Codable, Hashable {
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
    let media_type: String?
    
    
    func getResultTitle() -> String {
        return (name ?? title) ?? "- -"
    }
    
    func getMediaType() -> String {
        if media_type == "movie" {
            return "Movie"
        } else if media_type == "tv" {
            return "TV Serie"
        } else {
            return "Person"
        }
    }
    
    func getReleaseDate() -> String {
        return String((release_date?.dropLast(6) ?? first_air_date?.dropLast(6)) ?? "- -")
    }
}
