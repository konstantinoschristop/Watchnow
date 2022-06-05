//
//  GetSimilarModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 5/6/22.
//

import Foundation

struct GetSimilarModel: Codable {
    var page: Int?
    var results: [Result]?
    var total_pages, total_results: Int?
}

