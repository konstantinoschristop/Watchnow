//
//  MoviesView.swift
//  Watchnow
//
//  Created by k.christopoulos on 1/8/21.
//

import SwiftUI

struct MoviesView: View {
    
    @ObservedObject var moviesViewModel: MoviesViewModel
    
    var body: some View {
        ContentMainView(viewModel: moviesViewModel,
                        sections: [.trendingMovies,
                                   .streamingServicesMovies,
                                   .latestMovies,
                                   .popularMovies,
                                   .upcomingMovies,
                                   .topRatedMovies])
    }
}
