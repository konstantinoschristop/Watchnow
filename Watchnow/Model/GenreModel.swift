//
//  GenreModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 10/7/22.
//

import Foundation
import SwiftUI

struct GenreModel: Codable {
    var genres: [Genres]?
    
    func getAvailableGenres(ids: [Int]?) -> [Genres]? {
        
        guard let ids = ids else {
            return []
        }

        return genres?.filter { ids.contains($0.id ?? 0) }
    }
}

struct Genres: Codable, Hashable {
    var id: Int?
    var name: String?
}
