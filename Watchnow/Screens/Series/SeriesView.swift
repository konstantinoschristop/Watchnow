//
//  SeriesView.swift
//  Watchnow
//
//  Created by k.christopoulos on 30/11/21.
//

import SwiftUI

struct SeriesView: View {
    
    @ObservedObject var seriesViewModel: SeriesViewModel
    
    var body: some View {
        // `latestSeries` (Critics' Choice) was a horizontal poster scroll
        // sourced from TMDB's TV `top_rated` endpoint — exactly what
        // `topRatedSeries` (Top 10) shows. Replacing it instead of stacking
        // both keeps the screen's content unique row-to-row.
        ContentMainView(viewModel: seriesViewModel,
                        sections: [.trendingSeries,
                                   .streamingServicesSeries,
                                   .airingTodaySeries,
                                   .popularSeries,
                                   .topRatedSeries])
    }
}
