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
    @Published var listNeedsUpdate = false {
        didSet {
            refreshDataIfNeeded()
        }
    }
    
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

extension WatchlistViewModel {
    
    var results: [Result]? {
        get { model.results }
        set { model.results = newValue }
    }
    
    var savedMovies: [Result]? {
        get { model.savedMovies }
        set { model.savedMovies = newValue }
    }
    
    var savedSeries: [Result]? {
        get { model.savedSeries }
        set { model.savedSeries = newValue }
    }
    
    var showingMovies: Bool {
        get { model.showingMovies }
        set { model.showingMovies = newValue }
    }
    
    var showingSeries: Bool {
        get { model.showingSeries }
        set { model.showingSeries = newValue }
    }
}
