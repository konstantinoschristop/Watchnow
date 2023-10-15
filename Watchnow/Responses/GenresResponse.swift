//
//  GenreModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 10/7/22.
//

import Foundation
import SwiftUI

struct GenresResponse: Codable {
    var genres: [Genres]?
}

struct Genres: Codable, Hashable {
    var id: Int?
    var name: String?
}
