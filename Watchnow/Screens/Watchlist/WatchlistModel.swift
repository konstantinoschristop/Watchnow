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

    // MARK: - Layout

    /// How saved titles are presented. Persisted by the view through
    /// `@AppStorage` rather than held here, because a layout preference
    /// should outlive the process — unlike `selectedFilter`, which is
    /// deliberately per-session.
    enum Layout: String, CaseIterable, Identifiable {
        case grid
        case list

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .grid: return "square.grid.2x2.fill"
            case .list: return "list.bullet"
            }
        }

        var title: String {
            switch self {
            case .grid: return String(localized: "Grid", comment: "Watchlist layout option")
            case .list: return String(localized: "List", comment: "Watchlist layout option")
            }
        }
    }

    // MARK: - State

    var results:        [Result]?
    var selectedFilter: FolderFilter = .all
}
