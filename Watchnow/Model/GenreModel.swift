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
    
    func getAvailableGenres(ids: [Int]?) -> [Genres?] {
        
        guard let ids = ids else {
            return []
        }

        var genres: [Genres?] = []
        
        ids.forEach({ id in
            genres.append(self.genres?.first(where: { $0.id == id }))
        })
        
        return genres
    }
}

struct Genres: Codable, Hashable {
    var id: Int?
    var name: String?
}
