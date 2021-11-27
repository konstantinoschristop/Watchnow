//
//  UpcomingMoviesViewModel.swift
//  Watchnow
//
//  Created by k.christopoulos on 1/8/21.
//

import Foundation
import SwiftUI

class UpcomingMoviesViewModel {
    
    let api = APIKeys()
    
    var movieIDs: [String] = []
    var movieTitles: [String] = []
    var movieRatings: [Double] = []
    var movieBackdrops: [URL] = []
    
    init(dataModel: UpcomingMoviesModel) {
            
        for (index,result) in dataModel.results.enumerated() {
//            if index > 9 {
//                break
//            }
            
            if let backdrop = result.backdrop_path {
                movieIDs.append(String(result.id))
                movieTitles.append(result.title)
                
                guard let backdropUrl = URL(string: api.imageKey + backdrop) else {
                    return
                }
                movieRatings.append(result.vote_average)
                movieBackdrops.append(backdropUrl)
            } else {
                continue
            }
            
        }
    }
}
