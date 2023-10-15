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
                        let model = ContentDetailsModel(screenType: .tv, result: featuredSerie)
                        let vm = ContentDetailsViewModel(model: model)
                        ContentDetailsView(detailsViewModel: vm)
                    } label: {
                        MenuFeaturedView(content: featuredSerie,
                                         overlayContent: overlayContent(for: featuredSerie),
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

extension SeriesView {
    
    @ViewBuilder
    func overlayContent(for content: Result) -> some View {
        ZStack {
            LinearGradient(colors: [.clear,
                                    .black.opacity(0.6)],
                           startPoint: .center,
                           endPoint: .bottom)
            
            ZStack(alignment: .bottom) {
                Rectangle()
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, maxHeight: 120)
                    .blur(radius: 20)
                    .opacity(0.5)
                
                VStack(alignment: .center, spacing: 3) {
                    Text("Featured Now")
                        .font(.custom("AvenirNext-Regular", size: 20))
                    
                    Text(content.getResultTitle())
                        .font(.custom("AvenirNext-Bold", size: 25))
                        .multilineTextAlignment(.center)
                    
                    HStack {
                        Text(content.getReleaseDate(addSeparator: false))
                        Text(" | ")
                        HStack(spacing: 5) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.orange)
                            Text(String(format: "%.1f", content.vote_average ?? "-"))
                        }
                    }
                    .font(.custom("AvenirNext-Regular", size: 18))
                }
                .foregroundColor(.white)
                .shadow(color: .black, radius: 3)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding()
            }
        }
    }
}
