//
//  SerieView.swift
//  Watchnow
//
//  Created by k.christopoulos on 30/11/21.
//

import SwiftUI

struct SerieView: View {
    
    @StateObject var airingTodaySeriesVM = AiringTodaySeriesViewModel(service: SerieService())
    @StateObject var popularSeriesVM = PopularSeriesViewModel(service: SerieService())
    @StateObject var trendingSeriesVM = TrendingSeriesViewModel(service: SerieService())
    
    var body: some View {
        
        Group {
            if popularSeriesVM.popularSeries.results.isEmpty {
                ProgressView()
            } else {
                List {
                    TopView(results: popularSeriesVM.popularSeries.results, viewTitle: "Popular Series", screenType: .serie)
                        .listRowSeparatorTint(.clear)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
                    
                    BottomView(results: airingTodaySeriesVM.airingTodaySeries.results, viewTitle: "On Air Today", screenType: .serie)
                        .listRowSeparatorTint(.clear)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    
                    BottomView(results: trendingSeriesVM.trendingSeries.results, viewTitle: "Trending Today", screenType: .serie)
                        .listRowSeparatorTint(.clear)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
                .listStyle(.plain)
            }
        }
        .task {
            await airingTodaySeriesVM.getAiringTodaySeries()
            await popularSeriesVM.getPopularSeries()
            await trendingSeriesVM.getTrendingSeries()
        }
        .refreshable {
            await airingTodaySeriesVM.getAiringTodaySeries()
            await popularSeriesVM.getPopularSeries()
            await trendingSeriesVM.getTrendingSeries()
        }
    }
}
