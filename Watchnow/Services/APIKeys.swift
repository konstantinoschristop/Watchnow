//
//  APIKeys.swift
//  Watchnow
//
//  Created by k.christopoulos on 1/8/21.
//

import Foundation

class APIKeys {
    
    let imageKey = "https://image.tmdb.org/t/p/original/"
    
    let apikey = "?api_key=8a5d569103b429228d23a32db4b9a426&language=en-US"
    
    let upcomingMovies = "https://api.themoviedb.org/3/movie/upcoming?api_key=8a5d569103b429228d23a32db4b9a426&language=en-US"
    
    let popularMovies = "https://api.themoviedb.org/3/movie/popular?api_key=8a5d569103b429228d23a32db4b9a426&language=en-US"
    
    let movieGenres = "https://api.themoviedb.org/3/genre/movie/list?api_key=8a5d569103b429228d23a32db4b9a426&language=en-US"
    
    let movieDetails = "https://api.themoviedb.org/3/movie/" // + movieID + apikey
    
    let similarMovie = "https://api.themoviedb.org/3/movie/"  // +  movieID/similar + apikey
}
