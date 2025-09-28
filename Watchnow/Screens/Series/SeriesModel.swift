//
//  SeriesModel.swift
//  Watchnow
//
//  Created by k.christopoulos on 14/10/23.
//

import Foundation

struct SeriesModel {
    
    var popularSeries: ContentListResult?
    var airingTodaySeries: ContentListResult?
    var trendingSeries: ContentListResult? {
        didSet {
            self.featuredSerie = trendingSeries?.getResults()[randomFeaturedIndex]
        }
    }
    var latestSeries: ContentListResult?
    
    let randomFeaturedIndex = Int.random(in: 0...19)
    var featuredSerie: Result?
}
