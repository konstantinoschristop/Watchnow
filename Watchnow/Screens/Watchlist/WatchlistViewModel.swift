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
    /// Ids marked watched, for the covers' badges. Held here, not asked of
    /// `WatchedStore` per cover — that's a `@UserDefault`, a full decode a
    /// time — and refreshed with the list, under the same rules.
    @Published private(set) var watchedIDs: Set<Int> = []

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
        // And when it changes on this device — a details screen refreshing
        // its entry, a save from another tab — once it's out of sight.
        NotificationCenter.default.addObserver(
            forName: WatchlistManager.didChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.storageChanged() }
        }
    }

    // MARK: - Refreshing

    /// The stored list and its services as last read, so a refresh that
    /// finds them unchanged publishes nothing.
    private var loadedStorage: [Data?] = []

    /// The watchlist is on screen — or on its way on or off it: from its
    /// `onAppear`, which fires as a swipe back to it begins, to its
    /// `onDisappear`, which fires once a pushed details screen has finished
    /// covering it. Redrawing the covers anywhere in there breaks the zoom
    /// between them and the details screen — mid-push it flashed the screen
    /// black, mid-swipe-back it cancelled the swipe. Plain properties, not
    /// published: setting them must not redraw anything either.
    private var isOnScreen = false
    /// A change landed while the watchlist was on screen; applied once it
    /// isn't, or once `transitionAllowance` has passed.
    private var refreshPending = false
    private var pendingFlush: Task<Void, Never>?

    /// How long a change that lands on screen is held back: longer than a
    /// push or a swipe back takes. A push that finishes sooner applies it
    /// sooner, from `onDisappear`. Still on screen once it's passed, there's
    /// no transition left to protect — the user is looking at the list, or
    /// at a sheet over it, which fires no disappear — so it's applied then.
    /// Held until the next disappear instead, a write landing just after a
    /// swipe back (a details fetch finishing late) stayed hidden for as long
    /// as the user stayed on the tab.
    private let transitionAllowance: Duration = .seconds(1)

    func screenAppeared() {
        isOnScreen = true
    }

    func screenDisappeared() {
        isOnScreen = false
        applyPendingRefresh()
    }

    /// Changes made while the watchlist is on screen are mostly its own — a
    /// removal, a reorder — and those refresh it themselves, straight away;
    /// for them this finds nothing new. What arrives from elsewhere waits
    /// out `transitionAllowance`, or until the list is covered or away.
    private func storageChanged() {
        guard isOnScreen else {
            refreshDataIfNeeded()
            return
        }
        refreshPending = true
        guard pendingFlush == nil else { return }
        let allowance = transitionAllowance
        pendingFlush = Task { [weak self] in
            try? await Task.sleep(for: allowance)
            guard !Task.isCancelled else { return }
            self?.applyPendingRefresh()
        }
    }

    private func applyPendingRefresh() {
        pendingFlush?.cancel()
        pendingFlush = nil
        guard refreshPending else { return }
        refreshPending = false
        refreshDataIfNeeded()
    }

    private func fetchResultsFromWatchList() {
        let storage = ["watchlist", "watchlistProviders"].map { UserDefaults.standard.data(forKey: $0) }
        if results == nil || storage != loadedStorage {
            loadedStorage = storage
            self.results = WatchlistManager.watchlist
        }
        let watched = WatchedStore.watchedIDs
        if watched != watchedIDs { watchedIDs = watched }
    }

    func refreshDataIfNeeded() {
        fetchResultsFromWatchList()
    }

    /// The watchlist marked one itself — its own change, shown at once.
    func setWatched(_ id: Int, _ watched: Bool) {
        if watched { watchedIDs.insert(id) } else { watchedIDs.remove(id) }
    }

    // MARK: - Data derivation

    /// Full watchlist in display order — newest-added first. Storage is
    /// oldest → newest (append-on-add), so we reverse for display. Type
    /// is just metadata on each row; organisation is driven by folders.
    ///
    /// Reads the published copy rather than `WatchlistManager.watchlist`.
    /// That property is a `@UserDefault`, so every single access runs a
    /// full `JSONDecoder` pass over the entire saved list — and one render
    /// of the watchlist screen touches this once for the grid, once for the
    /// album row, once for the empty check, and once more per folder card.
    /// On a list of any size that was the "changing folder is laggy":
    /// half a dozen complete decodes per frame. `results` is refreshed by
    /// `fetchResultsFromWatchList()` on init, after a removal or reorder, on
    /// an iCloud merge, and on any other change on this device once the
    /// watchlist is out of sight or past any transition (`storageChanged()`)
    /// — every path that can change it.
    var savedAll: [Result] {
        Array((results ?? []).reversed())
    }

    func isWatchListEmpty() -> Bool {
        (results ?? []).isEmpty
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

    // MARK: - Folder covers

    /// The titles filed in `folder`, newest-saved first — the covers the
    /// folder's album card fans. Reuses `savedAll` rather than re-reading
    /// storage so the card and the grid can never disagree about what's
    /// inside a folder.
    func items(in folder: Folder) -> [Result] {
        savedAll.filter {
            guard let id = $0.id else { return false }
            return folderStore.folderID(for: id) == folder.id
        }
    }

    // MARK: - Item removal

    /// Removes a title from the watchlist and fires the confirmation toast.
    ///
    /// The list view gets this behaviour from `GenericListView`'s trailing
    /// swipe action; the poster grid has no row edge to swipe, so its
    /// context menu routes here instead. Both paths end at the same
    /// `WatchlistManager` call, so folder membership and the saved-date
    /// record are cleaned up identically either way.
    func remove(_ result: Result) {
        WatchlistManager.removeFromWatchList(result: result)
        // Re-publishes the list; see `itemRemoved`.
        itemRemoved(result: result)
        showRemovedAlert = true
    }

    /// Called by `GenericListView`'s trailing swipe once the title is out of
    /// storage. Has to re-publish: `savedAll` reads the cached `results`
    /// copy rather than `WatchlistManager.watchlist`, so without this the
    /// swiped row stayed on screen (with its swipe action flipped to "Add to
    /// Watchlist") and the album cards kept their old counts until the tab
    /// was left and re-entered.
    func itemRemoved(result: Result) {
        _ = result
        refreshDataIfNeeded()
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
