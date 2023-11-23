//
//  MoviesView.swift
//  Watchnow
//
//  Created by k.christopoulos on 1/8/21.
//

import SwiftUI

struct MoviesView: View {
    
    @StateObject var moviesViewModel: MoviesViewModel
    @State var showNavBar: Bool = false
    
    var body: some View {
        
        Group {
            ScrollView(showsIndicators: false) {
                if let featuredMovie = moviesViewModel.featuredMovie {
                    NavigationLink {
                        let model = ContentDetailsModel(screenType: .movie, result: featuredMovie)
                        let vm = ContentDetailsViewModel(model: model)
                        ContentDetailsView(detailsViewModel: vm)
                    } label: {
                        MenuFeaturedView(imageURL: featuredMovie.getResultPosterURL(),
                                         overlayContent: overlayContent(for: featuredMovie),
                                         showNavBar: $showNavBar)
                    }
                }
                VStack {
                    if let upcomingMovies = moviesViewModel.getUpcomingMovieResults() {
                        TopView(results: upcomingMovies,
                                viewTitle: "Upcoming Movies",
                                screenType: .movie,
                                viewModel: moviesViewModel,
                                viewSection: .upcomingMovies)
                    }
                    
                    if let results = moviesViewModel.getPopularMovieResults() {
                        BottomView(results: results,
                                   viewTitle: "Popular Movies",
                                   screenType: .movie,
                                   viewModel: moviesViewModel,
                                   viewSection: .popularMovies)
                    }
                    
                    if let results = moviesViewModel.getTrendingMovieResults() {
                        BottomView(results: results,
                                   viewTitle: "Trending Today",
                                   screenType: .movie,
                                   viewModel: moviesViewModel,
                                   viewSection: .trendingMovies)
                    }
                    
                    if let results = moviesViewModel.getLatestMovieResults() {
                        BottomView(results: results,
                                   viewTitle: "Now Playing Movies",
                                   screenType: .movie,
                                   viewModel: moviesViewModel,
                                   viewSection: .latestMovies)
                    }
                }
                //                        AdBannerView()
                //                            .frame(height: 50)
                //                            .padding(.bottom)
            }
        }
        .redacted(reason: moviesViewModel.finishedLoadingContent ? [] : .placeholder)
        .navigationTitle("Movies")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(!showNavBar)
        .task {
            await moviesViewModel.getUpcomingMovies(page: moviesViewModel.upcomingMoviesCurrentPage)
            await moviesViewModel.getPopularMovies(page: moviesViewModel.popularMoviesCurrentPage)
            await moviesViewModel.getTrendingMovies(page: moviesViewModel.trendingMoviesCurrentPage)
            await moviesViewModel.getLatestMovies(page: moviesViewModel.latestMoviesCurrentPage)
        }
        .onChange(of: moviesViewModel.upcomingMoviesCurrentPage) { newValue in
            Task {
                await moviesViewModel.getUpcomingMovies(page: newValue)
            }
        }
        .onChange(of: moviesViewModel.popularMoviesCurrentPage) { newValue in
            Task {
                await moviesViewModel.getPopularMovies(page: newValue)
            }
        }
        .onChange(of: moviesViewModel.trendingMoviesCurrentPage) { newValue in
            Task {
                await moviesViewModel.getTrendingMovies(page: newValue)
            }
        }
        .onChange(of: moviesViewModel.latestMoviesCurrentPage) { newValue in
            Task {
                await moviesViewModel.getLatestMovies(page: newValue)
            }
        }
    }
}

extension MoviesView {
    
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
                    
                    Spacer()
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
