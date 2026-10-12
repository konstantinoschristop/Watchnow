//
//  GenreModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 10/7/22.
//

import Foundation
import SwiftUI

struct GenresResponse: Codable {
    var genres: [Genres]?
}

struct Genres: Codable, Hashable {
    var id: Int?
    var name: String?

    /// The name to show, from the same list every other screen names genres
    /// from. Falls back to the name this response came with.
    @MainActor var displayName: String {
        id.flatMap(GenreNames.shared.tmdbName) ?? name ?? ""
    }
}

/// TMDB's genre names, in the language TMDB is asked for: what every screen
/// calls a genre — feed chips and pills, list rows, title pages, search,
/// Movie Night. One source, so a genre reads the same wherever it appears.
///
/// Loaded from TMDB's movie and TV genre lists and kept per language, so a
/// launch shows the names straight away and only refreshes them. Until the
/// first load ever succeeds, the app's bundled names stand in.
@MainActor @Observable
final class GenreNames {
    static let shared = GenreNames()

    /// id → name for the current TMDB language. Empty until first loaded.
    private(set) var names: [Int: String]

    private static let storageKey = "tmdbGenreNames"

    private init() {
        let stored = UserDefaults.standard.dictionary(forKey: Self.storageKey) as? [String: [String: String]]
        names = (stored?[API.language] ?? [:]).reduce(into: [:]) { result, entry in
            if let id = Int(entry.key) { result[id] = entry.value }
        }
    }

    /// TMDB's name for a genre, if it has been loaded.
    func tmdbName(for id: Int) -> String? {
        names[id]
    }

    /// TMDB's name, or the bundled one before TMDB's list has ever loaded.
    func name(for id: Int) -> String? {
        names[id] ?? bundledGenreNames[id]
    }

    /// Fetches both lists. Movie names win where an id is in both; they
    /// agree in practice. A failed fetch keeps what was there.
    func refresh(using service: ServiceInvocation = ServiceInvocation()) async {
        let tv = (try? await service.fetchGenres(screenType: .tv))?.genres ?? []
        let movie = (try? await service.fetchGenres(screenType: .movie))?.genres ?? []
        var fresh: [Int: String] = [:]
        for genre in tv + movie {
            if let id = genre.id, let name = genre.name, !name.isEmpty { fresh[id] = name }
        }
        guard !fresh.isEmpty else { return }
        names = fresh

        var stored = UserDefaults.standard.dictionary(forKey: Self.storageKey) as? [String: [String: String]] ?? [:]
        stored[API.language] = Dictionary(uniqueKeysWithValues: fresh.map { (String($0.key), $0.value) })
        UserDefaults.standard.set(stored, forKey: Self.storageKey)
    }
}
