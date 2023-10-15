//
//  SeriesView.swift
//  Watchnow
//
//  Created by k.christopoulos on 30/11/21.
//

import SwiftUI

struct SeriesView: View {
    
    @StateObject var seriesViewModel: SeriesViewModel
    @State var showNavBar: Bool = false
    
    var body: some View {
        
        Group {
            ScrollView(showsIndicators: false) {
                if let featuredSerie = seriesViewModel.featuredSerie {
                    NavigationLink {
                        ContentDetailsView(result: featuredSerie, screenType: .tv)
                    } label: {
                        MenuFeaturedView(content: featuredSerie,
                                         showNavBar: $showNavBar)
                    }
                }
                
                LazyVStack {
                    if let results = seriesViewModel.popularSeries?.results {
                        TopView(results: results,
                                viewTitle: "Popular Series",
                                screenType: .tv,
                                viewModel: seriesViewModel,
                                viewSection: .popularSeries)
                    }
                    
                    if let results =  seriesViewModel.trendingSeries?.results {
                        BottomView(results: results,
                                   viewTitle: "Trending Today",
                                   screenType: .tv,
                                   viewModel: seriesViewModel,
                                   viewSection: .trendingSeries)
                    }
                    
                    if let results = seriesViewModel.latestSeries?.results {
                        BottomView(results: results,
                                   viewTitle: "Top Rated Series",
                                   screenType: .tv,
                                   viewModel: seriesViewModel,
                                   viewSection: .latestSeries)
                    }
                    
                    if let results = seriesViewModel.airingTodaySeries?.results {
                        BottomView(results: results,
                                   viewTitle: "On Air Today",
                                   screenType: .tv,
                                   viewModel: seriesViewModel,
                                   viewSection: .airingTodaySeries)
                    }
                }
                
                //                        AdBannerView()
                //                            .frame(height: 50)
                //                            .padding(.bottom)
            }
            .redacted(reason: seriesViewModel.finishedLoadingContent ? [] : .placeholder)
            .navigationTitle("Series")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(!showNavBar)
        }
        .task {
            await seriesViewModel.getTrendingSeries(page: seriesViewModel.trendingSeriesCurrentPage)
            await seriesViewModel.getPopularSeries(page: seriesViewModel.popularSeriesCurrentPage)
            await seriesViewModel.getLatestSeries(page: seriesViewModel.latestSeriesCurrentPage)
            await seriesViewModel.getAiringTodaySeries(page: seriesViewModel.airingTodaySeriesCurrentPage)
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
        .onChange(of: seriesViewModel.latestSeriesCurrentPage) { newValue in
            Task {
                await seriesViewModel.getLatestSeries(page: newValue)
            }
        }
    }
}
