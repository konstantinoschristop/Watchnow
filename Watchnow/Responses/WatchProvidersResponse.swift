//
//   WatchProvidersResponse.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 1/8/23.
//

import Foundation

// MARK: - Welcome
struct WatchProvidersResponse: Codable {
    var id: Int?
    var results: [String: ProviderResults]?
}

// MARK: - Result
struct ProviderResults: Codable {
    var link: String?
    /// Subscription streaming (Netflix, Disney+, etc.) — primary surface on
    /// the details screen; this is why most users open the app.
    var flatrate: [Flatrate]?
    /// Per-title rentals (Apple TV, Amazon, Google Play, …).
    var rent: [Flatrate]?
    /// Per-title purchases. Often overlaps with `rent` because the same
    /// storefronts offer both; shown as a separate subgroup so users who
    /// specifically want to own (not rent) can see it at a glance.
    var buy: [Flatrate]?
}

// MARK: - Flatrate
struct Flatrate: Codable {
    var logoPath: String?
    var providerID: Int?
    var providerName: String?
    var displayPriority: Int?

    enum CodingKeys: String, CodingKey {
        case logoPath = "logo_path"
        case providerID = "provider_id"
        case providerName = "provider_name"
        case displayPriority = "display_priority"
    }
}
