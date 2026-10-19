//
//  EpisodesViewModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 15/8/22.
//

import Foundation

/// Episodes per season for the seasons sheet, fetched on demand and kept for
/// as long as the sheet is open.
///
/// It used to hold one season at a time and clear it on every switch, so
/// going back to a season meant a skeleton and a second fetch for data the
/// sheet had seconds earlier.
@MainActor
class EpisodesViewModel: ObservableObject {

    enum Load {
        case loading
        case loaded(EpisodesResponse)
        case failed
    }

    @Published private(set) var seasons: [Int: Load] = [:]

    private let service: any DetailServiceProtocol
    let seriesID: Int

    init(service: any DetailServiceProtocol = ServiceInvocation(),
         seriesID: Int) {

        self.service = service
        self.seriesID = seriesID
    }

    /// Starts a fetch for `seasonNumber` unless one has already succeeded or
    /// is in flight. Not tied to the caller's task, so swiping past a season
    /// doesn't cancel its fetch halfway and leave it stuck loading.
    func ensureEpisodes(seasonNumber: Int) {
        switch seasons[seasonNumber] {
        case .loading, .loaded: return
        case .failed, nil: break
        }
        seasons[seasonNumber] = .loading
        Task {
            do {
                let response = try await service.fetchEpisodes(seriesID: seriesID, seasonNumber: seasonNumber)
                seasons[seasonNumber] = .loaded(response)
            } catch {
                seasons[seasonNumber] = .failed
            }
        }
    }
}
