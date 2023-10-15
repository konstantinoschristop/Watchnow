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
                        ContentDetailsView(result: featuredMovie, screenType: .movie)
                    } label: {
                        MenuFeaturedView(content: featuredMovie,
                                         showNavBar: $showNavBar)
                    }
                }
                LazyVStack {
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
