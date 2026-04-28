//
//  WatchlistViewModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 6/8/22.
//

import Foundation

@MainActor
class WatchlistViewModel: ObservableObject, BaseSwipeActionsProtocol {

    @Published private var model:              WatchlistModel
    @Published var showRemovedAlert        = false
    @Published var showAddedAlert          = false
    @Published var showWatchedRemovedAlert = false

    init(model: WatchlistModel) {
        self.model = model
        self.fetchResultsFromWatchList()
    }

    private func fetchResultsFromWatchList() {
        self.results = WatchlistManager.watchlist
        getSavedMovies()
        getSavedSeries()
        getSavedWatched()
    }

    func refreshDataIfNeeded() {
        fetchResultsFromWatchList()
    }

    // MARK: - Data derivation

    private func getSavedMovies() {
        let raw = WatchlistManager.watchlist.filter { $0.media_type == "movie" }
        savedMovies = model.applySort(raw)
    }

    private func getSavedSeries() {
        let raw = WatchlistManager.watchlist.filter { $0.media_type == "tv" }
        savedSeries = model.applySort(raw)
    }

    private func getSavedWatched() {
        // Watched list always shows newest-first regardless of the sort preference.
        savedWatched = WatchedManager.shared.watchedlist.reversed()
    }

    func isWatchListEmpty() -> Bool {
        WatchlistManager.watchlist.isEmpty
    }

    // MARK: - Sort

    func setSortOrder(_ order: WatchlistModel.SortOrder) {
        model.sortOrder = order
        getSavedMovies()
        getSavedSeries()
    }

    // MARK: - Item removal

    func itemRemoved(result: Result) {
        savedMovies.removeAll { $0 == result }
        savedSeries.removeAll { $0 == result }
    }

    func watchedItemRemoved(result: Result) {
        WatchedManager.shared.removeFromWatched(result: result)
        savedWatched.removeAll { $0 == result }
        showWatchedRemovedAlert = true
    }
}

// MARK: - Model bridges

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

    var savedWatched: [Result] {
        get { model.savedWatched }
        set { model.savedWatched = newValue }
    }

    var sortOrder: WatchlistModel.SortOrder {
        model.sortOrder
    }
}
