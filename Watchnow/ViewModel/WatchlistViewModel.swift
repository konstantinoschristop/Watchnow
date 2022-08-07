//
//  WatchlistViewModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 6/8/22.
//

import Foundation

@MainActor
class WatchlistViewModel: ObservableObject {
    
    @Published var results: [Result]?
    @Published private(set) var savedMovies: [Result]?
    @Published private(set) var savedSeries: [Result]?
    
    @Published var showAlert = false
    
    init() {
        self.fetchResultsFromWatchList()
    }
    
    private func fetchResultsFromWatchList() {
        self.results = WatchlistManager.watchlist
        self.getSavedMovies()
        self.getSavedSeries()
    }
    
    func refreshDataIfNeeded() {
        self.fetchResultsFromWatchList()
    }
    
    private func getSavedMovies() {
        
        self.savedMovies = WatchlistManager.watchlist.filter({ $0.media_type == "movie" })
    }
    
    private func getSavedSeries() {
        
        self.savedSeries = WatchlistManager.watchlist.filter({ $0.media_type == "tv" })
    }
    
    func isWatchListEmpty() -> Bool {
        return WatchlistManager.watchlist.isEmpty == true
    }
}
