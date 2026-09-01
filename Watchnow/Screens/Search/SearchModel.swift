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
        
        func getTitle() -> String {
            
            switch self {
            case .all:
                return "All"
            case .movies:
                return "Movies"
            case .series:
                return "TV Series"
            case .actors:
                return "Actors"
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
            case .movies: return "Movies"
            case .series: return "TV Series"
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
        let name: String
        let symbol: String
        let movieID: Int?
        let seriesID: Int?

        var id: String { name }

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
            .init(name: "Action",      symbol: "bolt.fill",              movieID: 28,    seriesID: 10759),
            .init(name: "Comedy",      symbol: "face.smiling.inverse",   movieID: 35,    seriesID: 35),
            .init(name: "Drama",       symbol: "theatermasks.fill",      movieID: 18,    seriesID: 18),
            .init(name: "Sci-Fi",      symbol: "sparkles",               movieID: 878,   seriesID: 10765),
            .init(name: "Horror",      symbol: "moon.stars.fill",        movieID: 27,    seriesID: nil),
            .init(name: "Thriller",    symbol: "eye.fill",               movieID: 53,    seriesID: nil),
            .init(name: "Romance",     symbol: "heart.fill",             movieID: 10749, seriesID: nil),
            .init(name: "Crime",       symbol: "key.fill",            movieID: 80,    seriesID: 80),
            .init(name: "Fantasy",     symbol: "wand.and.sparkles",         movieID: 14,    seriesID: nil),
            .init(name: "Animation",   symbol: "paintpalette.fill",      movieID: 16,    seriesID: 16),
            .init(name: "Mystery",     symbol: "questionmark.circle.fill", movieID: 9648, seriesID: 9648),
            .init(name: "Documentary", symbol: "book.closed.fill",       movieID: 99,    seriesID: 99),
            .init(name: "Family",      symbol: "figure.2.and.child.holdinghands", movieID: 10751, seriesID: 10751),
            .init(name: "Adventure",   symbol: "map.fill",               movieID: 12,    seriesID: nil),
            .init(name: "War",         symbol: "shield.fill",            movieID: 10752, seriesID: 10768),
            .init(name: "Western",     symbol: "hat.widebrim.fill",          movieID: 37,    seriesID: 37),
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
