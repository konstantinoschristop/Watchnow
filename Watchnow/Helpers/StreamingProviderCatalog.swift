//
//  StreamingProviderCatalog.swift
//  Watchnow
//
//  The one definition of "which streaming services do we show, and in what
//  order".
//
//  This list used to live inside `MovieNightViewModel`, which was fine while
//  Movie Night's setup screen was the only place a user could say what they
//  subscribe to. Onboarding asks the same question on first launch and
//  Settings has to let them change the answer later, so the curation moved
//  here rather than being copied twice. The chip *views* still differ per
//  screen — Movie Night's carry its own motion — but which services exist
//  and which comes first is decided once, here.
//

import Foundation

@MainActor
enum StreamingProviderCatalog {

    /// Major subscription services in rough global-recognition order.
    ///
    /// Curated by stable provider id rather than taken from TMDB's own
    /// `display_priority`, which is erratic across regions (it ranks Sun Nxt
    /// above Hulu in the US) and carries no monetization tag — so an
    /// unfiltered list mixes rent/buy storefronts and ad-supported tiers in
    /// with the subscriptions people mean when they say "what I have".
    ///
    /// id 350 ("Apple TV") is the Apple TV+ subscription; the rent/buy
    /// "Apple TV Store" (id 2) is intentionally absent. Regional services sit
    /// at the end so they only surface where the majors don't.
    nonisolated static let subscriptionProviders: [Int] = [
        8,         // Netflix
        9, 119,    // Amazon Prime Video (+ regional id)
        337,       // Disney+
        350,       // Apple TV (Apple TV+)
        1899, 384, // Max / HBO Max
        15,        // Hulu
        531,       // Paramount+
        386, 387,  // Peacock
        283,       // Crunchyroll
        37,        // Showtime
        43,        // Starz
        520,       // Discovery+
        526,       // AMC+
        11,        // MUBI
        151,       // BritBox
        39,        // NOW
        29,        // Sky Go
        122,       // Disney+ Hotstar (regional)
        309,       // Sun Nxt (regional)
        232,       // ZEE5 (regional)
        220        // JioCinema (regional)
    ]

    /// provider_id → its index above (lower = shown first).
    nonisolated static let rank: [Int: Int] =
        Dictionary(subscriptionProviders.enumerated().map { ($1, $0) },
                   uniquingKeysWith: { first, _ in first })

    /// Filter a region's raw catalogue down to the curated set, in curated
    /// order. Pure, so the ordering rule is testable without a network.
    nonisolated static func curated(from providers: [WatchProvider]?) -> [WatchProvider] {
        (providers ?? [])
            .filter { rank[$0.provider_id] != nil }
            .sorted { (rank[$0.provider_id] ?? .max) < (rank[$1.provider_id] ?? .max) }
    }

    /// The region's curated services. Soft-fails to an empty list: a screen
    /// that can't offer the question just doesn't ask it.
    static func load(region: String,
                     using service: ServiceInvocation = ServiceInvocation()) async -> [WatchProvider] {
        let response = try? await service.fetchProviders(screenType: .movie, region: region)
        return curated(from: response?.results)
    }
}
