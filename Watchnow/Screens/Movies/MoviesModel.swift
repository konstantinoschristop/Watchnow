//
//  MoviesModel.swift
//  Watchnow
//
//  Created by k.christopoulos on 14/10/23.
//

import Foundation

struct MoviesModel {
    
    var upcomingMovies: GenericReultResponse? {
        didSet {
            self.featuredMovie = upcomingMovies?.results[randomFeaturedIndex]
        }
    }
     var popularMovies: GenericReultResponse?
     var trendingMovies: GenericReultResponse?
     var latestMovies: GenericReultResponse?
    
     var upcomingMoviesCurrentPage = 1
     var popularMoviesCurrentPage = 1
     var trendingMoviesCurrentPage = 1
     var latestMoviesCurrentPage = 1
    
    let randomFeaturedIndex = Int.random(in: 0...19)
    var featuredMovie: Result?
}
