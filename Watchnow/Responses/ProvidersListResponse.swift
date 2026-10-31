//
//  ProvidersListResponse.swift
//  Watchnow
//
//  Decodes TMDB's `/watch/providers/{movie|tv}?watch_region=XX` endpoint —
//  the region-scoped catalogue of streaming services TMDB tracks. Powers
//  the "Browse by streaming service" tile row on the Movies / Series tabs.
//
//  Which of them the app shows, and in what order, is
//  `StreamingProviderCatalog`'s call — TMDB's `display_priority` ranks
//  storefronts and niche services above some of the majors.
//

import Foundation

struct ProvidersListResponse: Codable {
    let results: [WatchProvider]?
}

/// `Sendable` stated rather than inferred, for the reason `Result` gives.
struct WatchProvider: Codable, Hashable, Identifiable, Sendable {
    let provider_id: Int
    let provider_name: String
    let logo_path: String?
    /// Lower = more prominent, by TMDB's reckoning. The top-level value is
    /// the same in every region (Netflix 0, HBO Max 26), so it says little
    /// about what a given country actually watches.
    let display_priority: Int?

    var id: Int { provider_id }

    var logoURL: URL? {
        guard let path = logo_path, !path.isEmpty else { return nil }
        return URL(string: API.Common.imageUrl(imageId: path))
    }
}
