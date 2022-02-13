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
            if let results = popularSeriesVM.popularSeries?.results {
                List {
                    TopView(results: results, viewTitle: "Popular Series", screenType: .tv)
                        .listRowSeparatorTint(.clear)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
                    
                    if let results = airingTodaySeriesVM.airingTodaySeries?.results {
                        BottomView(results: results, viewTitle: "On Air Today", screenType: .tv)
                            .listRowSeparatorTint(.clear)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                    
                    if let results =  trendingSeriesVM.trendingSeries?.results {
                        BottomView(results: results, viewTitle: "Trending Today", screenType: .tv)
                            .listRowSeparatorTint(.clear)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                }
                .listStyle(.plain)
            } else {
                ProgressView()
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
