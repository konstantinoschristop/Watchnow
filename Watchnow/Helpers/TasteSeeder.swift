//
//  TasteSeeder.swift
//  Watchnow
//
//  Turns onboarding's "tap five you've loved" into the taste signal the rest
//  of the app already understands.
//
//  It adds no new modelling. A pick made here goes through exactly the same
//  door as the heart button on a details screen — `TasteProfile.like` — so
//  Movie Coach, Movie Night and the recommendation graph all see it the
//  moment onboarding ends, without knowing onboarding exists.
//
//  The extraction is separated from the writing so the mapping can be tested
//  without a store: `signals(from:)` is pure, `apply(_:)` is the two lines
//  that touch state.
//

import Foundation

enum TasteSeeder {

    /// What one loved pick contributes.
    struct Signal: Equatable {
        let id: Int
        let genreIDs: [Int]
        let language: String?
    }

    /// Extract the signals from a set of picks.
    ///
    /// Anything without an id is dropped — it could not be attributed — and
    /// duplicates collapse, so a double tap can't weight a genre twice.
    /// Order is preserved, because the first pick is the one the finish
    /// sequence shows a Coach verdict for.
    static func signals(from picks: [Result]) -> [Signal] {
        var seen = Set<Int>()
        return picks.compactMap { pick in
            guard let id = pick.id, seen.insert(id).inserted else { return nil }
            return Signal(id: id,
                          genreIDs: pick.genre_ids ?? [],
                          language: pick.original_language)
        }
    }

    /// Record the picks as explicit likes.
    @MainActor
    static func apply(_ picks: [Result]) {
        for signal in signals(from: picks) {
            TasteProfile.like(id: signal.id,
                              genreIDs: signal.genreIDs,
                              language: signal.language)
        }
    }
}
