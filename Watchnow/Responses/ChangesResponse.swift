//
//  ChangesResponse.swift
//  Watchnow
//

import Foundation

/// TMDB `/movie/{id}/changes` and `/tv/{id}/changes` payload.
///
/// Only the change *keys* are decoded ("videos", "release_dates", "status",
/// "season", …). The per-item values are deliberately ignored: they're
/// heterogeneous JSON that varies by key, and Watchnow doesn't need them —
/// the keys say *which domain moved*, and the snapshot diff in
/// `ChangeClassifier` supplies the actual facts from typed endpoints.
/// This makes `/changes` a cheap pre-filter: one request tells us whether
/// a title is worth re-fetching at all.
struct TitleChangesResponse: Codable {
    let changes: [TitleChangeGroup]?

    var changedKeys: Set<String> {
        Set((changes ?? []).compactMap(\.key))
    }
}

struct TitleChangeGroup: Codable {
    let key: String?
}
