//
//  WatchlistViewModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 6/8/22.
//

import Foundation

@MainActor
class WatchlistViewModel: ObservableObject, BaseSwipeActionsProtocol {    
    
    @Published var results: [Result]?
    @Published private(set) var savedMovies: [Result]?
    @Published private(set) var savedSeries: [Result]?
    @Published private(set) var showingMovies = true
    @Published private(set) var showingSeries = true
    
    @Published var showRemovedAlert = false
    @Published var showAddedAlert = false
    @Published var listNeedsUpdate = false {
        didSet {
            refreshDataIfNeeded()
        }
    }
    
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
        
        self.savedMovies = WatchlistManager.watchlist.reversed().filter({ $0.media_type == "movie" })
    }
    
    private func getSavedSeries() {
        
        self.savedSeries = WatchlistManager.watchlist.reversed().filter({ $0.media_type == "tv" })
    }
    
    func isWatchListEmpty() -> Bool {
        return WatchlistManager.watchlist.isEmpty == true
    }
    
    func getSectionArrowIcon(screenType: ScreenTypes) -> String {
        
        switch screenType {
        case .movie:
            return showingMovies ? "arrow.down.right.and.arrow.up.left.circle.fill" : "arrow.up.backward.and.arrow.down.forward.circle.fill"
        case .tv:
            return showingSeries ? "arrow.down.right.and.arrow.up.left.circle.fill" : "arrow.up.backward.and.arrow.down.forward.circle.fill"
        default:
            return ""
        }
    }
    
    func sectionArrowAction(screenType: ScreenTypes) {
        
        switch screenType {
        case .movie:
            showingMovies.toggle()
        case .tv:
            showingSeries.toggle()
        default:
            return
        }
    }
}
