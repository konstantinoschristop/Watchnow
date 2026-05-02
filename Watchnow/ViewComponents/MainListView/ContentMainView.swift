//
//  ContentMainView.swift
//  Watchnow
//
//  Created by k.christopoulos on 28/9/25.
//

import SwiftUI

/// Stable TMDB genre ID → display name map (movies + TV combined).
/// Lives outside `ContentMainView` because Swift doesn't allow static
/// stored properties in generic types. Module-internal so `ListSection`
/// (and any future consumer) can resolve genre IDs without duplicating
/// the table.
let tmdbGenreNames: [Int: String] = [
    28: "Action",     12: "Adventure",   16: "Animation",   35: "Comedy",
    80: "Crime",      99: "Documentary", 18: "Drama",     10751: "Family",
    14: "Fantasy",    36: "History",     27: "Horror",     9648: "Mystery",
 10749: "Romance",   878: "Sci-Fi",      53: "Thriller",  10752: "War",
    37: "Western",10759: "Action",    10765: "Sci-Fi",   10768: "War",
 10762: "Kids",   10763: "News",      10764: "Reality",  10766: "Soap"
]

struct ContentMainView<VM: BaseContentViewModel>: View {
    @ObservedObject var viewModel: VM
    @Namespace private var namespace

    let sections: [ViewSections]

    /// Currently active genre filter. nil = "All" (no filter).
    @State private var selectedGenreID: Int? = nil

    // MARK: - Screen-type helpers

    private var isMovieTab: Bool {
        sections.allSatisfy { $0.screenType == .movie }
    }

    /// Accent tint that matches the tab's section headers.
    private var tint: Color { isMovieTab ? .accentColor : .purple }

    /// Genre shortlist for this tab. IDs are stable TMDB genre IDs.
    private var popularGenres: [PopularGenre] {
        isMovieTab ? PopularGenre.movies : PopularGenre.series
    }

    // MARK: - Body

    var body: some View {
        Group {
            if viewModel.apiError && !viewModel.finishedLoadingContent {
                ContentUnavailableView {
                    Label("Couldn't load content", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("Check your connection and try again.")
                } actions: {
                    Button("Retry") {
                        Task { await viewModel.loadContent(resetFirst: true) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if !viewModel.finishedLoadingContent {
                // Shimmer skeleton — shown until all 4 sections have loaded.
                ScrollView(showsIndicators: false) {
                    SkeletonContentView(sections: sections)
                }
                .transition(.opacity)
            } else {
                ScrollView(showsIndicators: false) {
                    if let results = viewModel.featuredResult {
                        MenuFeaturedView(results: results,
                                         overlayContent: { result in overlayContent(for: result) },
                                         screenType: isMovieTab ? .movie : .tv)
                    }

                    genreFilterBar

                    LazyVStack(spacing: 6) {
                        ForEach(sections, id: \.self) { section in
                            // Streaming-services has a different data shape
                            // (providers + selected results, not the standard
                            // section list) so it goes through its own branch
                            // and consumes the view model directly.
                            if section.isStreamingServicesSection,
                               let providers = viewModel.providers, !providers.isEmpty {
                                StreamingServicesSection(viewModel: viewModel,
                                                         viewSection: section)
                            } else if let results = filteredResults(for: section) {
                                if section.isTopView {
                                    TopView(results: results,
                                            viewTitle: section.title,
                                            screenType: section.screenType,
                                            viewModel: viewModel,
                                            viewSection: section)
                                } else if section.isListSection {
                                    ListSection(results: results,
                                                screenType: section.screenType,
                                                viewSection: section,
                                                viewModel: viewModel)
                                } else if section.isTopTenSection {
                                    TopTenSection(results: results,
                                                  screenType: section.screenType,
                                                  viewSection: section,
                                                  viewModel: viewModel)
                                } else {
                                    BottomView(results: results,
                                               viewTitle: section.title,
                                               screenType: section.screenType,
                                               viewModel: viewModel,
                                               viewSection: section)
                                }
                            }
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: selectedGenreID)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: viewModel.finishedLoadingContent)
        .ignoresSafeArea(edges: .top)
        .onLoad { Task { await viewModel.loadContent(resetFirst: true) } }
        .toolbarTitleDisplayMode(.inlineLarge)
    }

    // MARK: - Genre filter bar

    private var genreFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" chip — clears the filter
                GenreChip(name: "All",
                          isSelected: selectedGenreID == nil,
                          tint: tint) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selectedGenreID = nil
                    }
                }

                ForEach(popularGenres) { genre in
                    GenreChip(name: genre.name,
                              isSelected: selectedGenreID == genre.id,
                              tint: tint) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            // Tapping the active chip toggles it off (back to All)
                            selectedGenreID = selectedGenreID == genre.id ? nil : genre.id
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Filtered results

    /// Returns the results for `section`, filtered by `selectedGenreID` when set.
    /// Returns nil when the filtered list is empty so the section hides itself.
    private func filteredResults(for section: ViewSections) -> [Result]? {
        let raw: [Result]?
        switch section {
        case .trendingMovies, .trendingSeries:    raw = viewModel.trending?.result.results
        case .popularMovies,  .popularSeries:     raw = viewModel.popular?.result.results
        case .upcomingMovies, .airingTodaySeries: raw = viewModel.special?.result.results
        case .latestMovies,   .latestSeries:      raw = viewModel.latest?.result.results
        case .topRatedMovies, .topRatedSeries:    raw = viewModel.topRated?.result.results
        // Streaming-services renders providers, not results — caller
        // handles it via its own branch in the dispatcher and never
        // reaches this point. Returning nil keeps the switch exhaustive
        // without inviting accidental use as a results source.
        case .streamingServicesMovies, .streamingServicesSeries: raw = nil
        }

        guard let raw else { return nil }
        guard let genreID = selectedGenreID else { return raw }

        let filtered = raw.filter { $0.genre_ids?.contains(genreID) == true }
        return filtered.isEmpty ? nil : filtered
    }
}

// MARK: - Genre chip

/// Neutral when not selected, accent fill when selected. The `tint`
/// parameter is kept for source-compatibility with callers but ignored —
/// the chip palette is global so the screen reads as one design system,
/// not a per-tab one.
private struct GenreChip: View {
    let name: String
    let isSelected: Bool
    let tint: Color   // unused — see note above
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background {
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
                }
                .overlay {
                    if !isSelected {
                        Capsule()
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Popular genres

/// Hardcoded shortlists using stable TMDB genre IDs.
/// These are the genres that appear most frequently across trending/popular
/// lists and give the most useful filter signal with just a single tap.
struct PopularGenre: Identifiable {
    let id: Int
    let name: String

    static let movies: [PopularGenre] = [
        .init(id: 28,  name: "Action"),
        .init(id: 35,  name: "Comedy"),
        .init(id: 18,  name: "Drama"),
        .init(id: 27,  name: "Horror"),
        .init(id: 878, name: "Sci-Fi"),
    ]

    static let series: [PopularGenre] = [
        .init(id: 10759, name: "Action"),
        .init(id: 18,    name: "Drama"),
        .init(id: 35,    name: "Comedy"),
        .init(id: 80,    name: "Crime"),
        .init(id: 10765, name: "Sci-Fi"),
    ]
}

// MARK: - Overlay content (home-screen carousel hero)

extension ContentMainView {

    @ViewBuilder
    func overlayContent(for content: Result) -> some View {
        ZStack(alignment: .bottom) {
            // Cinematic bottom gradient — stronger than before so text
            // stays legible on bright/pale posters.
            LinearGradient(
                stops: [
                    .init(color: .clear,               location: 0.25),
                    .init(color: .black.opacity(0.35),  location: 0.55),
                    .init(color: .black.opacity(0.75),  location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {

                // Title
                Text(content.getResultTitle())
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.6), radius: 4)

                // Meta: rating · year
                HStack(spacing: 6) {
                    if let rating = content.vote_average, rating > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(RatingStyle.tint(for: rating))
                            Text(String(format: "%.1f", rating))
                        }
                        Text("·").opacity(0.6)
                    }
                    let year = content.getReleaseDate(addSeparator: false)
                    if !year.isEmpty {
                        Text(year)
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.5), radius: 2)

                // Genre tags — up to 2, resolved from genre_ids
                let genres = resolvedGenres(for: content)
                if !genres.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(genres, id: \.self) { name in
                            Text(name)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Maps up to 2 genre IDs on a `Result` to their display names.
    private func resolvedGenres(for content: Result) -> [String] {
        guard let ids = content.genre_ids else { return [] }
        return ids.prefix(2).compactMap { tmdbGenreNames[$0] }
    }
}
