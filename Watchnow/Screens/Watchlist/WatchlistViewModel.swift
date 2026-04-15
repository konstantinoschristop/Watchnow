//
//  WatchlistViewModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 6/8/22.
//

import Foundation

@MainActor
class WatchlistViewModel: ObservableObject, BaseSwipeActionsProtocol {    
    
    @Published private var model: WatchlistModel
    @Published var showRemovedAlert = false
    @Published var showAddedAlert = false

    init(model: WatchlistModel) {
        self.model = model
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
        
        self.savedMovies = WatchlistManager.watchlist.reversed().filter({ $0.media_type == "movie" })
    }
    
    private func getSavedSeries() {
        
        self.savedSeries = WatchlistManager.watchlist.reversed().filter({ $0.media_type == "tv" })
    }
    
    func isWatchListEmpty() -> Bool {
        return WatchlistManager.watchlist.isEmpty == true
    }
    
    func itemRemoved(result: Result) {
        if let movieToRemove = self.savedMovies.firstIndex(of: result) {
            savedMovies.remove(at: movieToRemove)
        }
        if let seriesToRemove = self.savedSeries.firstIndex(of: result) {
            savedSeries.remove(at: seriesToRemove)
        }
    }
}

extension WatchlistViewModel {
    
    var results: [Result]? {
        get { model.results }
        set { model.results = newValue }
    }
    
    var savedMovies: [Result] {
        get { model.savedMovies }
        set { model.savedMovies = newValue }
    }
    
    var savedSeries: [Result] {
        get { model.savedSeries }
        set { model.savedSeries = newValue }
    }
    
}
