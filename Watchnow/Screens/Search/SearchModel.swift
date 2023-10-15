//
//  SearchModel.swift
//  Watchnow
//
//  Created by k.christopoulos on 14/10/23.
//

import Foundation

struct SearchModel {
    
    enum SearchChooserOptions: String, CaseIterable {
        case all = "All"
        case movies = "Movie"
        case series = "TV Serie"
        case actors = "Actor"
        
        func getTitle() -> String {
            
            switch self {
            case .all:
                return "All"
            case .movies:
                return "Movies"
            case .series:
                return "TV Series"
            case .actors:
                return "Actors"
            }
        }
    }
    
    var searchResponse: SearchResponse?
    var results: [Result]?
    var selectedChooser: SearchChooserOptions = .all 
}
