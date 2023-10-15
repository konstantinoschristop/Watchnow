//
//  ReviewsModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 5/6/22.
//

import Foundation

struct ResultReviewsResponse: Codable {
    var id, page: Int?
    var results: [Reviews]?
}

// MARK: - Reviews
struct Reviews: Codable, Hashable {
    
    var author: String?
    var author_details: AuthorDetails?
    var content, created_at, id, updated_at: String?
    var url: String?
}

// MARK: - AuthorDetails
struct AuthorDetails: Codable, Hashable {
    var name, username, avatar_path: String?
    var rating: Int?
}
