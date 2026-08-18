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
    var details: ResultDetailsResponse?
    var collection: CollectionResponse?
    var watchProviders: WatchProvidersResponse?
    var isInWatchList:   Bool = false
    var viewModelFinishedFetching: Bool = false
    /// Set once every parallel detail fetch has settled. Movie Coach waits
    /// for this so it builds its context (and generates) exactly once,
    /// instead of re-running as each individual request lands.
    var allSectionsLoaded: Bool = false
    
    var screenType: ScreenTypes
    var result: Result
    
    init(screenType: ScreenTypes,
         result: Result) {
        
        self.screenType = screenType
        self.result = result
        self.result.media_type = screenType == .movie ? "movie" : "tv"
    }
}
