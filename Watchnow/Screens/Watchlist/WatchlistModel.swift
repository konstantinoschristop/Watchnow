//
//  WatchlistModel.swift
//  Watchnow
//
//  Created by k.christopoulos on 14/10/23.
//

import Foundation

struct WatchlistModel {
    
    enum Tab: String, CaseIterable {
        case movies
        case series
        
        var title: String {
            switch self {
            case .movies:
                return "Movies"
            case .series:
                return "TV Series"
            }
        }
    }
    
    var results: [Result]?
    var savedMovies: [Result] = []
    var savedSeries: [Result] = []
}
