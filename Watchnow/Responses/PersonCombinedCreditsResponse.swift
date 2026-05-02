//
//  PersonCombinedCreditsResponse.swift
//  Watchnow
//
//  Decodes TMDB's `/person/{id}/combined_credits` endpoint, which returns
//  every movie + TV title a person has appeared in (cast) or worked on
//  (crew). Each entry already carries a `media_type` field of "movie" or
//  "tv", so the existing `Result` shape decodes cleanly.
//
//  Used by the actor sheet's "Known For" section when the caller couldn't
//  pre-load a `known_for` array — i.e. when the user opened the sheet by
//  tapping a cast row instead of a multi-search result.
//

import Foundation

struct PersonCombinedCreditsResponse: Codable {
    let cast: [Result]?
    let crew: [Result]?
}
