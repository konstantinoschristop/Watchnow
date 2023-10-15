//
//  SeriesModel.swift
//  Watchnow
//
//  Created by k.christopoulos on 14/10/23.
//

import Foundation

struct SeriesModel {
    
    var popularSeries: GenericReultResponse?
    var airingTodaySeries: GenericReultResponse?
    var trendingSeries: GenericReultResponse? {
        didSet {
            self.featuredSerie = trendingSeries?.results[randomFeaturedIndex]
        }
    }
    var latestSeries: GenericReultResponse?
    
    var popularSeriesCurrentPage = 1
    var airingTodaySeriesCurrentPage = 1
    var trendingSeriesCurrentPage = 1
    var latestSeriesCurrentPage = 1
    
    let randomFeaturedIndex = Int.random(in: 0...19)
    var featuredSerie: Result?
}
