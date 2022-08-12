//
//  WatchlistView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 6/8/22.
//

import Foundation
import SwiftUI
import AlertToast

struct WatchlistView: View {
    
    @StateObject var watchlistViewModel = WatchlistViewModel.init()
    
    var body: some View {
        
        Group {
            if watchlistViewModel.isWatchListEmpty() {
                Text("Your watchlist is empty!")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if let movies = watchlistViewModel.savedMovies,
                       movies.isEmpty == false {

                        self.getSectionTitle(title: "Movies")
                        GenericListView(results: movies, viewModel: watchlistViewModel)
                    }

                    if let series = watchlistViewModel.savedSeries,
                       series.isEmpty == false {

                        self.getSectionTitle(title: "TV Shows")
                        GenericListView(results: series, viewModel: watchlistViewModel)
                    }
                }
                .listStyle(.plain)
            }
        }
        .onAppear {
            watchlistViewModel.refreshDataIfNeeded()
        }
        .toast(isPresenting: $watchlistViewModel.showRemovedAlert, alert: {
            AlertToast(type: .systemImage("x.circle", .red), title: "Removed from Watchlist")
        })
    }
    
    func getSectionTitle(title: String) -> some View {
        
        return HStack {
            Text(title)
                .font(.system(size: 25, weight: .heavy))
            Spacer()
        }
        .listRowSeparatorTint(.clear)
        .listRowBackground(Color(.systemGray6))
        .padding(.horizontal)
        .padding(.init(top: 10, leading: 0, bottom: 5, trailing: 0))
    }
}
