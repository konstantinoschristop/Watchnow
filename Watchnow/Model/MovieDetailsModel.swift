//
//  MovieDetailsModel.swift
//  Watchnow
//
//  Created by k.christopoulos on 1/8/21.
//

import Foundation

struct MovieDetailsModel: Codable {
    let adult: Bool
    let backdrop_path: String
    let budget: Int
    let genres: [Genre]
    let homepage: String
    let id: Int
    let imdbID, original_title, overview: String
    let popularity: Double
    let poster_path: String
    let release_date: String
    let revenue, runtime: Int
    let status, tagline, title: String
    let video: Bool
    let vote_average: Double
    let vote_count: Int
}



