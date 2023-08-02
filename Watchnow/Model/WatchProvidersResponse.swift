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
    var results: [String: ProviderResulst]?
}

// MARK: - Result
struct ProviderResulst: Codable {
    var link: String?
    var flatrate: [Flatrate]?
    var rent: [Flatrate]?
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
