//
//  MoviesView.swift
//  Watchnow
//
//  Created by k.christopoulos on 1/8/21.
//

import SwiftUI

struct MoviesView: View {
    
    @StateObject var moviesViewModel: MoviesViewModel
    
    var body: some View {
        ContentMainView(viewModel: moviesViewModel,
                        sections: [.trendingMovies, .latestMovies, .popularMovies, .upcomingMovies])
    }
}
