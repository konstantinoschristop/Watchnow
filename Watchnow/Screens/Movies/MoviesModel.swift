//
//  MoviesModel.swift
//  Watchnow
//
//  Created by k.christopoulos on 14/10/23.
//

import Foundation

struct MoviesModel {
    
    var upcomingMovies: ContentListResult? {
        didSet {
            self.featuredMovie = trendingMovies?.getResults()[randomFeaturedIndex]
        }
    }
     var popularMovies: ContentListResult?
     var trendingMovies: ContentListResult?
     var latestMovies: ContentListResult?
    
    let randomFeaturedIndex = Int.random(in: 0...19)
    var featuredMovie: Result?
}

struct ContentListResult: LoadMoreContentProtocol {
  
    private(set) var result: GenericReultResponse
    var currentPage: Int = 1
    
    
    init(result: GenericReultResponse) {
        self.result = result
    }
    
    func getResults() -> [Result] {
        return result.results
    }
    
    mutating func appendResult(_ result: GenericReultResponse) {
        self.result.results.append(contentsOf: result.results)
    }
    
    mutating func incrementCurrentPage() {
        self.currentPage += 1
    }
}

protocol LoadMoreContentProtocol {
    
    var currentPage: Int { get set }
    var result: GenericReultResponse { get }
}

extension LoadMoreContentProtocol {
    
    func canLoadMoreContent() -> Bool {
        
        guard let totalPages = result.total_pages else {
            return false
        }
        return currentPage < totalPages
    }
}
