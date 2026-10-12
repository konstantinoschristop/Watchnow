//
//  SearchModel.swift
//  Watchnow
//
//  Created by k.christopoulos on 14/10/23.
//

import Foundation

struct SearchModel {
    
    enum SearchChooserOptions: String, CaseIterable {
        case all = "All"
        case movies = "Movie"
        case series = "TV Series"
        case actors = "Actor"
        
        /// The chip's label. `rawValue` is a key matched against
        /// `Result.getMediaType()`, never shown.
        func getTitle() -> String {
            
            switch self {
            case .all:
                return String(localized: "All", comment: "Search filter chip: every kind of result")
            case .movies:
                return String(localized: "Movies", comment: "Search filter chip")
            case .series:
                return String(localized: "TV Series", comment: "Search filter chip")
            case .actors:
                return String(localized: "Actors", comment: "Search filter chip: people")
            }
        }

        /// Empty-state title when this filter leaves nothing.
        var emptyTitle: String {
            switch self {
            case .all:    return String(localized: "No results", comment: "Search empty state")
            case .movies: return String(localized: "No movies", comment: "Search empty state for the Movies filter")
            case .series: return String(localized: "No TV series", comment: "Search empty state for the TV Series filter")
            case .actors: return String(localized: "No actors", comment: "Search empty state for the Actors filter")
            }
        }
    }

    /// Which trending feed the start screen's poster row is showing.
    /// Mirrors the Movies / Series split of the two home tabs so the row
    /// reads as a shortcut into familiar territory rather than a new
    /// taxonomy the user has to learn.
    enum TrendingScope: String, CaseIterable, Identifiable {
        case movies
        case series

        var id: String { rawValue }

        var title: String {
            switch self {
            case .movies: return String(localized: "Movies", comment: "Search start screen: trending scope")
            case .series: return String(localized: "TV Series", comment: "Search start screen: trending scope")
            }
        }

        var screenType: ScreenTypes {
            switch self {
            case .movies: return .movie
            case .series: return .tv
            }
        }
    }
    
    /// A browsable genre chip.
    ///
    /// Carries *both* TMDB genre IDs because the movie and TV taxonomies
    /// don't agree — "Action" is 28 on the movie side and 10759 on TV, and
    /// several genres (Horror, Thriller, Romance) simply don't exist as TV
    /// tags at all. Holding both lets one tap fan out to whichever
    /// endpoints can actually answer it, which is what keeps a genre browse
    /// as mixed-media as the multi-search it sits next to.
    struct Genre: Identifiable, Hashable {
        let symbol: String
        let movieID: Int?
        let seriesID: Int?

        /// Named as every other screen names it (`GenreNames`), after its
        /// movie genre — the TV id only for a genre movies don't have.
        @MainActor var name: String {
            (movieID ?? seriesID).flatMap(GenreNames.shared.name) ?? ""
        }

        /// The TMDB ids, not `name`: that's in the app's language.
        var id: String { "\(movieID ?? 0)/\(seriesID ?? 0)" }

        /// The `(screenType, genreID)` pairs this chip should query.
        var queries: [(ScreenTypes, Int)] {
            var out: [(ScreenTypes, Int)] = []
            if let movieID { out.append((.movie, movieID)) }
            if let seriesID { out.append((.tv, seriesID)) }
            return out
        }

        /// Curated shortlist rather than TMDB's full catalogue. The full
        /// list runs to 19 movie + 16 TV genres including near-duplicates
        /// ("Action & Adventure" vs "Action"), which would turn a browse
        /// shortcut into a wall of chips. These are the tags people
        /// actually reach for, ordered roughly by how often.
        static let browsable: [Genre] = [
            .init(symbol: "bolt.fill",              movieID: 28,    seriesID: 10759), // Action
            .init(symbol: "face.smiling.inverse",   movieID: 35,    seriesID: 35), // Comedy
            .init(symbol: "theatermasks.fill",      movieID: 18,    seriesID: 18), // Drama
            .init(symbol: "sparkles",               movieID: 878,   seriesID: 10765), // Sci-Fi
            .init(symbol: "moon.stars.fill",        movieID: 27,    seriesID: nil), // Horror
            .init(symbol: "eye.fill",               movieID: 53,    seriesID: nil), // Thriller
            .init(symbol: "heart.fill",             movieID: 10749, seriesID: nil), // Romance
            .init(symbol: "key.fill",            movieID: 80,    seriesID: 80), // Crime
            .init(symbol: "wand.and.sparkles",         movieID: 14,    seriesID: nil), // Fantasy
            .init(symbol: "paintpalette.fill",      movieID: 16,    seriesID: 16), // Animation
            .init(symbol: "questionmark.circle.fill", movieID: 9648, seriesID: 9648), // Mystery
            .init(symbol: "book.closed.fill",       movieID: 99,    seriesID: 99), // Documentary
            .init(symbol: "figure.2.and.child.holdinghands", movieID: 10751, seriesID: 10751), // Family
            .init(symbol: "map.fill",               movieID: 12,    seriesID: nil), // Adventure
            .init(symbol: "shield.fill",            movieID: 10752, seriesID: 10768), // War
            .init(symbol: "hat.widebrim.fill",          movieID: 37,    seriesID: 37), // Western
        ]
    }

    /// The text in the search field.
    ///
    /// Lives here rather than as `@State` in `SearchView` so that leaving
    /// the tab can clear it — the view's own state is out of reach from
    /// `ContentView`, which is where a tab change is observed.
    var query: String = ""

    var searchResponse: SearchResponse?
    var recentSearches: [String] = []
    var results: [Result]? {
        didSet {
            setFilteredArray()
        }
    }
    var filteredResults: [Result] = []
    var selectedChooser: SearchChooserOptions = .all {
        didSet {
            setFilteredArray()
        }
    }

    // MARK: - Trending (start screen)

    var trendingMovies: [Result] = []
    var trendingSeries: [Result] = []
    var trendingScope: TrendingScope = .movies
    var isLoadingTrending: Bool = false
    var trendingFailed: Bool = false

    /// Set while `results` came from a genre browse rather than a typed
    /// query. Drives the results header and the empty-state copy, both of
    /// which otherwise refer to a search string that doesn't exist here.
    var activeGenre: Genre?

    /// Discover page the active genre browse has reached. A typed search
    /// stays on page 1 — TMDB's multi endpoint returns the matches worth
    /// showing in one page, and nobody pages through a title match.
    var genrePage: Int = 1

    /// Whether the genre's feeds have another page. Drives the footer
    /// button; false also covers "we don't know yet".
    var genreHasMore: Bool = false

    /// Set only for the append, so the footer can show a spinner without
    /// the whole screen dropping to the loading skeleton.
    var isLoadingMoreGenre: Bool = false

    /// The feed matching the active scope. Empty until the fetch lands.
    var trending: [Result] {
        switch trendingScope {
        case .movies: return trendingMovies
        case .series: return trendingSeries
        }
    }

    /// True once *either* feed has arrived — the start screen uses this to
    /// decide between the shimmer skeleton and the real row, so flipping
    /// scope after the fetch never bounces back to a skeleton.
    var hasTrending: Bool {
        !trendingMovies.isEmpty || !trendingSeries.isEmpty
    }
    
    mutating func setFilteredArray() {
        
        if selectedChooser == .all {
            filteredResults = results ?? []
        } else {
            filteredResults = results?.filter { $0.getMediaType() == selectedChooser.rawValue } ?? []
        }
    }
}
