//
//  KeywordsResponse.swift
//  Watchnow
//

import Foundation

/// TMDB `/movie/{id}/keywords` and `/tv/{id}/keywords` payload.
///
/// Both endpoints return the same keyword objects, but movies nest them
/// under `keywords` while TV nests them under `results` — so both keys are
/// optional here and `all` papers over the difference for callers.
struct KeywordsResponse: Codable {
    let id: Int?
    /// Movie endpoint's array.
    let keywords: [Keyword]?
    /// TV endpoint's array.
    let results: [Keyword]?

    var all: [Keyword] { keywords ?? results ?? [] }
}

struct Keyword: Codable, Hashable {
    let id: Int?
    let name: String?
}
