//
//  WatchlistModel.swift
//  Watchnow
//
//  Created by k.christopoulos on 14/10/23.
//

import Foundation

struct WatchlistModel {

    // MARK: - Tab

    enum Tab: String, CaseIterable {
        case movies
        case series
        case watched

        /// Short label used inside the nav-bar underline tabs.
        var title: String {
            switch self {
            case .movies:  return "Movies"
            case .series:  return "Series"
            case .watched: return "Watched"
            }
        }
    }

    // MARK: - Sort order

    enum SortOrder: String, CaseIterable, Identifiable {
        case dateAdded = "Date Added"
        case rating    = "Rating"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .dateAdded: return "clock"
            case .rating:    return "star.fill"
            }
        }
    }

    // MARK: - State

    var results:      [Result]?
    var savedMovies:  [Result] = []
    var savedSeries:  [Result] = []
    var savedWatched: [Result] = []
    var sortOrder:    SortOrder = .dateAdded

    // MARK: - Sorting

    /// Applies the active sort order to a pre-filtered array.
    func applySort(_ items: [Result]) -> [Result] {
        switch sortOrder {
        case .dateAdded:
            return items.reversed()
        case .rating:
            // Items with no rating sort to the end.
            return items.sorted {
                ($0.vote_average ?? -1) > ($1.vote_average ?? -1)
            }
        }
    }
}
