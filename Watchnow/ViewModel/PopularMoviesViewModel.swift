//
//  PopularMoviesViewModel.swift
//  Watchnow
//
//  Created by k.christopoulos on 1/8/21.
//

import Foundation

class PopularMoviesViewModel {
    
    let api = APIKeys()
    
    var movieIDs: [String] = []
    var movieTitles: [String] = []
    var movieRatings: [Double] = []
    var moviePosters: [URL] = []
    
    init(dataModel: PopularMoviesModel) {
        for (index,result) in dataModel.results.enumerated() {
//            if index > 9 {
//                break
//            }
                movieIDs.append(String(result.id))
                movieTitles.append(result.title)
                
                guard let posterUrl = URL(string: api.imageKey + result.poster_path) else {
                    return
                }
                movieRatings.append(result.vote_average)
                moviePosters.append(posterUrl)
        }
    }
}
