//
//  SeriesView.swift
//  Watchnow
//
//  Created by k.christopoulos on 30/11/21.
//

import SwiftUI

struct SeriesView: View {
    
    @StateObject var seriesViewModel: SeriesViewModel
    @Namespace private var namespace
    
    var body: some View {
        
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                if let featuredSerie = seriesViewModel.featuredSerie {
                    NavigationLink {
                        let model = ContentDetailsModel(screenType: .tv, result: featuredSerie)
                        let vm = ContentDetailsViewModel(model: model)
                        ContentDetailsView(detailsViewModel: vm)
                            .navigationTransition(.zoom(sourceID: "zoom", in: namespace))
                    } label: {
                        MenuFeaturedView(imageURL: featuredSerie.getResultPosterURL(),
                                         overlayContent: overlayContent(for: featuredSerie),
                                         showNavBar: .constant(true))
                    }
                }
                
                if let results =  seriesViewModel.trendingSeries?.results {
                    TopView(results: results,
                            viewTitle: "🔥 Binge-Worthy Today",
                            screenType: .tv,
                            viewModel: seriesViewModel,
                            viewSection: .trendingSeries)
                }
                
                if let results = seriesViewModel.airingTodaySeries?.results {
                    BottomView(results: results,
                               viewTitle: "Fresh Episodes",
                               screenType: .tv,
                               viewModel: seriesViewModel,
                               viewSection: .airingTodaySeries)
                }
                
                if let results = seriesViewModel.popularSeries?.results {
                    BottomView(results: results,
                               viewTitle: "Most Watched",
                               screenType: .tv,
                               viewModel: seriesViewModel,
                               viewSection: .popularSeries)
                }
                
                
                if let results = seriesViewModel.latestSeries?.results {
                    BottomView(results: results,
                               viewTitle: "Critics' Choice",
                               screenType: .tv,
                               viewModel: seriesViewModel,
                               viewSection: .latestSeries)
                }
            }
        }
        .onLoad {
            Task {
                await seriesViewModel.loadContent()
            }
        }
        .redacted(reason: seriesViewModel.finishedLoadingContent ? [] : .placeholder)
        .navigationBarHidden(true)
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
                    Text("Spotlight")
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
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(.white)
                .shadow(color: .black, radius: 3)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding()
            }
        }
    }
}
