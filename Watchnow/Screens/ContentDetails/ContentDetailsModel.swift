//
//  ContentDetailsModel.swift
//  Watchnow
//
//  Created by k.christopoulos on 15/10/23.
//

import Foundation

enum ScreenTypes: String {
    case movie
    case tv
    case person
}

struct ContentDetailsModel {
    
    var credits: ResultCreditsResponse?
    var similar: GetSimilarModel?
    var reviews: ResultReviewsResponse?
    var videos: VideoResponse?
    var details: ResultDetailsReponse?
    var collection: CollectionResponse?
    var images: ImagesResponse?
    var watchProviders: WatchProvidersResponse?
    var isInWatchList: Bool
    var viewModelFinishedFetching: Bool = false
    
    var screenType: ScreenTypes
    var result: Result
    
    init(screenType: ScreenTypes,
         result: Result) {
        
        self.screenType = screenType
        self.result = result
        self.isInWatchList = WatchlistManager.existsInWatchList(result: result)
        self.result.media_type = screenType == .movie ? "movie" : "tv"
    }
}
