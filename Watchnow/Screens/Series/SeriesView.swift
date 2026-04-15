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
        ContentMainView(viewModel: seriesViewModel,
                        sections: [.trendingSeries, .airingTodaySeries, .popularSeries, .latestSeries])
    }
}
