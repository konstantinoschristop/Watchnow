//
//  WatchlistViewModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 6/8/22.
//

import Foundation

@MainActor
class WatchlistViewModel: ObservableObject, BaseSwipeActionsProtocol {

    @Published private var model:       WatchlistModel
    @Published var showRemovedAlert = false
    @Published var showAddedAlert   = false

    /// Plain reference to the folder singleton. The view observes
    /// `FolderManager.shared` itself via `@ObservedObject` to react to
    /// folder / membership changes; this property is just a convenience
    /// so VM methods don't have to repeat `FolderManager.shared` each time.
    var folderStore: FolderManager { FolderManager.shared }

    init(model: WatchlistModel) {
        self.model = model
        self.fetchResultsFromWatchList()

        // Refresh when the watchlist (or its folders) sync in from another
        // device, so the list updates live without needing a tab switch.
        NotificationCenter.default.addObserver(
            forName: CloudSync.didMergeRemoteChanges,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshDataIfNeeded() }
        }
    }

    private func fetchResultsFromWatchList() {
        self.results = WatchlistManager.watchlist
    }

    func refreshDataIfNeeded() {
        fetchResultsFromWatchList()
    }

    // MARK: - Data derivation

    /// Full watchlist in display order — newest-added first. Storage is
    /// oldest → newest (append-on-add), so we reverse for display. Type
    /// is just metadata on each row; organisation is driven by folders.
    var savedAll: [Result] {
        Array(WatchlistManager.watchlist.reversed())
    }

    func isWatchListEmpty() -> Bool {
        WatchlistManager.watchlist.isEmpty
    }

    // MARK: - Filter (folder chip row)

    func setFilter(_ filter: WatchlistModel.FolderFilter) {
        model.selectedFilter = filter
    }

    /// Applies the active folder filter to `items`.
    func applyFolderFilter(_ items: [Result]) -> [Result] {
        switch selectedFilter {
        case .all:
            return items
        case .folder(let folderID):
            return items.filter {
                guard let id = $0.id else { return false }
                return folderStore.folderID(for: id) == folderID
            }
        }
    }

    // MARK: - Item removal

    func itemRemoved(result: Result) {
        // No-op: there are no derived per-type arrays to prune anymore.
        // The view re-reads `savedAll` (which pulls from
        // `WatchlistManager.watchlist`) on the next render, so removed
        // items disappear automatically.
        _ = result
    }

    // MARK: - Reorder

    /// Apply a user-initiated reorder against the visible subset of the
    /// watchlist. Items outside `displayed` (filtered to another folder)
    /// keep their storage positions; the slots in storage that held the
    /// `displayed` items get rewritten with the new relative order.
    ///
    /// Storage is oldest → newest; display is newest → oldest. The new
    /// visible order is reversed before being written back.
    func reorder(displayed: [Result], from source: IndexSet, to destination: Int) {

        var newDisplayed = displayed
        newDisplayed.move(fromOffsets: source, toOffset: destination)

        // Storage is oldest → newest; the visible list is newest → oldest.
        var iterator = Array(newDisplayed.reversed()).makeIterator()
        let visibleIDs = Set(displayed.compactMap(\.id))

        var storage = WatchlistManager.watchlist
        for i in storage.indices {
            guard let id = storage[i].id, visibleIDs.contains(id),
                  let next = iterator.next() else { continue }
            storage[i] = next
        }
        WatchlistManager.watchlist = storage

        // Force a republish so SwiftUI re-reads `savedAll`.
        fetchResultsFromWatchList()
    }
}

// MARK: - Model bridges

extension WatchlistViewModel {

    var results: [Result]? {
        get { model.results }
        set { model.results = newValue }
    }

    var selectedFilter: WatchlistModel.FolderFilter {
        model.selectedFilter
    }
}
