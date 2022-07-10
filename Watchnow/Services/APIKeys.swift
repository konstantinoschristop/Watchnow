//
//  APIKeys.swift
//  Watchnow
//
//  Created by k.christopoulos on 1/8/21.
//

import Foundation

class APIKeys {
    
    let baseURL = "https://api.themoviedb.org/3/"
    
    let imageKey = "https://image.tmdb.org/t/p/original/"
    
    let imageCastKey = "https://image.tmdb.org/t/p/original"
    
    let apikey = "?api_key=8a5d569103b429228d23a32db4b9a426&language=en-US"
    
    let popularMovies = "https://api.themoviedb.org/3/movie/now_playing?api_key=8a5d569103b429228d23a32db4b9a426&language=en-US"
    
    let upcomingMovies = "https://api.themoviedb.org/3/movie/upcoming?api_key=8a5d569103b429228d23a32db4b9a426&language=en-US&page=2"
    
    let trendingMovies = "https://api.themoviedb.org/3/trending/movie/day?api_key=8a5d569103b429228d23a32db4b9a426"
    
    let popularSeries = "https://api.themoviedb.org/3/tv/popular?api_key=8a5d569103b429228d23a32db4b9a426&language=en-US&page=1"
    
    let airingTodaySeries = "https://api.themoviedb.org/3/tv/on_the_air?api_key=8a5d569103b429228d23a32db4b9a426&language=en-US&page=1"
    
    let trendingSeries = "https://api.themoviedb.org/3/trending/tv/day?api_key=8a5d569103b429228d23a32db4b9a426"
    
    let credits = "credits?api_key=8a5d569103b429228d23a32db4b9a426&language=en-US"
    
    let movieGenres = "https://api.themoviedb.org/3/genre/movie/list?api_key=8a5d569103b429228d23a32db4b9a426&language=en-US"
        
    let similar = "similar?api_key=8a5d569103b429228d23a32db4b9a426&language=en-US"
    
    let reviews = "reviews?api_key=8a5d569103b429228d23a32db4b9a426&language=en-US"

    let searchURL = "https://api.themoviedb.org/3/search/multi?api_key=8a5d569103b429228d23a32db4b9a426&language=en-US&include_adult=false&query="
}
