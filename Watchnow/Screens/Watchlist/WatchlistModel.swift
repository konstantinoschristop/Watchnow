//
//  WatchlistModel.swift
//  Watchnow
//
//  Created by k.christopoulos on 14/10/23.
//

import Foundation

struct WatchlistModel {

    // MARK: - Folder filter

    /// Which slice of the watchlist the user wants to see. Lives on the
    /// model so the chip-row selection survives across renders, but is
    /// not persisted across launches.
    enum FolderFilter: Hashable {
        case all
        case folder(UUID)
    }

    // MARK: - State

    var results:        [Result]?
    var selectedFilter: FolderFilter = .all
}
