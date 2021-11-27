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
    let genre_ids: [Int]
    let id: Int
    let original_title: String
    let overview: String
    let popularity: Double
    let poster_path: String
    let release_date: String
    let title: String
    let video: Bool
    let vote_average: Double
}
