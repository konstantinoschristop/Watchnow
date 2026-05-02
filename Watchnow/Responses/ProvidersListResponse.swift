//
//  ProvidersListResponse.swift
//  Watchnow
//
//  Decodes TMDB's `/watch/providers/{movie|tv}?watch_region=XX` endpoint —
//  the region-scoped catalogue of streaming services TMDB tracks. Powers
//  the "Browse by streaming service" tile row on the Movies / Series tabs.
//
//  Each provider carries a `display_priority` per region; sorting by that
//  field puts Netflix / Apple TV+ / Disney+ at the top and obscure niche
//  services at the bottom.
//

import Foundation

struct ProvidersListResponse: Codable {
    let results: [WatchProvider]?
}

struct WatchProvider: Codable, Hashable, Identifiable {
    let provider_id: Int
    let provider_name: String
    let logo_path: String?
    /// Lower = more prominent. TMDB returns this region-scoped, so the
    /// same provider can have different priorities in different countries.
    let display_priority: Int?

    var id: Int { provider_id }

    var logoURL: URL? {
        guard let path = logo_path, !path.isEmpty else { return nil }
        return URL(string: API.Common.imageUrl(imageId: path))
    }
}
