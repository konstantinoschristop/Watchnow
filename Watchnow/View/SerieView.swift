//
//  SerieView.swift
//  Watchnow
//
//  Created by k.christopoulos on 30/11/21.
//

import SwiftUI

struct SerieView: View {
    
    @StateObject var seriesViewModel = SeriesViewModel()
    @State var imageHeight: CGFloat = 200
    
    var body: some View {
        
        ZStack(alignment: .top) {
            Group {
                ScrollView(showsIndicators: false) {
                    if let featuredSerie = seriesViewModel.featuredSerie {
                        NavigationLink {
                            ContentDetailsView(result: featuredSerie, screenType: .tv)
                        } label: {
                            MenuFeaturedView(content: featuredSerie,
                                             heightChanged: { imageHeight in
                                self.imageHeight = imageHeight
                            })
                        }
                    }
                    
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
                    
                    //                        AdBannerView()
                    //                            .frame(height: 50)
                    //                            .padding(.bottom)
                }
            }
            .redacted(reason: seriesViewModel.finishedLoadingContent ? [] : .placeholder)
            GeometryReader { geometry in
                NavigationBar(title:  imageHeight < 150 ? "Series" : "",
                              opacity: imageHeight < 150 ? 1 : 0)
                .frame(width: geometry.size.width,
                       height: 45 + geometry.safeAreaInsets.top)
                .ignoresSafeArea()
            }
        }
        .task {
            await seriesViewModel.getPopularSeries(page: seriesViewModel.popularSeriesCurrentPage)
            await seriesViewModel.getTrendingSeries(page: seriesViewModel.trendingSeriesCurrentPage)
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
