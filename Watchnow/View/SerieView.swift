//
//  SerieView.swift
//  Watchnow
//
//  Created by k.christopoulos on 30/11/21.
//

import SwiftUI

struct SerieView: View {
    
    @StateObject var seriesViewModel = SeriesViewModel()
    
    var body: some View {
        
        Group {
            if let results = seriesViewModel.popularSeries?.results {
                List {
                    TopView(results: results,
                            viewTitle: "Popular Series",
                            screenType: .tv,
                            viewModel: seriesViewModel,
                            viewSection: .popularSeries)
                        .listRowSeparatorTint(.clear)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
                    
                    if let results =  seriesViewModel.trendingSeries?.results {
                        BottomView(results: results,
                                   viewTitle: "Trending Today",
                                   screenType: .tv,
                                   viewModel: seriesViewModel,
                                   viewSection: .trendingSeries)
                            .listRowSeparatorTint(.clear)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                    
                    if let results = seriesViewModel.airingTodaySeries?.results {
                        BottomView(results: results,
                                   viewTitle: "On Air Today",
                                   screenType: .tv,
                                   viewModel: seriesViewModel,
                                   viewSection: .airingTodaySeries)
                            .listRowSeparatorTint(.clear)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                }
                .listStyle(.plain)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await seriesViewModel.getPopularSeries(page: seriesViewModel.popularSeriesCurrentPage)
            await seriesViewModel.getAiringTodaySeries(page: seriesViewModel.airingTodaySeriesCurrentPage)
            await seriesViewModel.getTrendingSeries(page: seriesViewModel.trendingSeriesCurrentPage)
        }
        .refreshable {
            await seriesViewModel.getPopularSeries(page: seriesViewModel.popularSeriesCurrentPage)
            await seriesViewModel.getAiringTodaySeries(page: seriesViewModel.airingTodaySeriesCurrentPage)
            await seriesViewModel.getTrendingSeries(page: seriesViewModel.trendingSeriesCurrentPage)
        }
        .onChange(of: seriesViewModel.popularSeriesCurrentPage) { newValue in
            Task {
                await seriesViewModel.getPopularSeries(page: newValue)
            }
        }
        .onChange(of: seriesViewModel.airingTodaySeriesCurrentPage) { newValue in
            Task {
                await seriesViewModel.getAiringTodaySeries(page: newValue)
            }
        }
        .onChange(of: seriesViewModel.trendingSeriesCurrentPage) { newValue in
            Task {
                await seriesViewModel.getTrendingSeries(page: newValue)
            }
        }
    }
}
