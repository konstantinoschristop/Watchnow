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

    /// Drives the Movie Night full-screen cover (Movies tab only).
    @State private var movieNightPresented = false

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

                    // Movie Night entry point — Movies tab only (the feature
                    // is movies-only for now). Sits high in the feed, under
                    // the genre chips, so it's the first thing after the hero.
                    if isMovieTab {
                        MovieNightBanner { movieNightPresented = true }
                    }

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
                                    // Hidden — results need review before re-enabling.
                                    EmptyView()
                                } else {
                                    BottomView(results: results,
                                               viewTitle: section.title,
                                               screenType: section.screenType,
                                               viewModel: viewModel,
                                               viewSection: section,
                                               adSlot: adSlot(for: section))
                                }
                            }
                        }

                        // Subtle inline banner — sits below all content sections,
                        // takes up no space until a creative loads.
                        InlineBannerSection()
                            .padding(.top, 4)
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
        .fullScreenCover(isPresented: $movieNightPresented) {
            MovieNightView()
        }
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
        // One haptic per selection change. Hosted on the container so
        // we don't fire N times for the N chips that all see their
        // `isSelected` flip during a single user tap.
        .sensoryFeedback(.selection, trigger: selectedGenreID)
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

    /// Where to slot the native ad card. Limited to the one prominent
    /// "Most Watched" (popular) row, after the 3rd poster, so it reads as
    /// part of the scroll without peppering ad requests across every row.
    private func adSlot(for section: ViewSections) -> Int? {
        switch section {
        case .popularMovies, .popularSeries:   return 3
        case .topRatedMovies, .topRatedSeries: return 3
        default: return nil
        }
    }
}

// MARK: - Genre chip

/// Neutral when not selected, accent fill when selected. The `tint`
/// parameter is kept for source-compatibility with callers but ignored —
/// the chip palette is global so the screen reads as one design system,
/// not a per-tab one.
///
/// On iOS 26+ the capsule is rendered with the system liquid-glass
/// material: `.regular` (frosted) when idle, `.regular.tinted()` (accent-
/// washed glass) when selected. This replaces the opaque fill + stroke
/// with a translucent, depth-aware surface that reacts to the content
/// behind it. Pre-iOS 26 devices keep the existing solid-fill style.
private struct GenreChip: View {
    let name: String
    let isSelected: Bool
    let tint: Color   // unused — see note above
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            chipLabel
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.68), value: isSelected)
    }

    // Glass is intentionally omitted here — genre chips sit inside the
    // main vertical scroll view and re-compositing glass on every scroll
    // frame causes measurable lag. Static glass surfaces (hero pills,
    // page indicator, action buttons) are fine; interactive chips in a
    // scrolling container are not.
    private var chipLabel: some View {
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
}

// MARK: - Movie Night banner

/// Prominent entry point to the Movie Night flow, shown near the top of the
/// Movies feed: an accent-filled card with the popcorn mark, a one-line pitch
/// and a chevron, tappable across its whole surface.
private struct MovieNightBanner: View {
    let action: () -> Void

    /// Drives the diagonal shine sweep across the card.
    @State private var shimmer: CGFloat = -1

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                iconBadge
                copy
                Spacer(minLength: 8)
                miniDeck
            }
            .padding(16)
            .background { gradient }
            .overlay { shine }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
            }
            .shadow(color: Color.accentColor.opacity(0.45), radius: 16, y: 8)
        }
        .buttonStyle(PressableCardStyle())
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, 10)
        .onAppear {
            withAnimation(.linear(duration: 3.6).repeatForever(autoreverses: false)) {
                shimmer = 1
            }
        }
    }

    // MARK: - Pieces

    private var iconBadge: some View {
        ZStack {
            Circle().fill(.white.opacity(0.20))
            Circle().strokeBorder(.white.opacity(0.30), lineWidth: 0.5)
            Image(systemName: "popcorn.fill")
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 52, height: 52)
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("Movie Night")
                    .font(.system(size: 18, weight: .heavy))
                Text("NEW")
                    .font(.system(size: 10, weight: .heavy))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.white.opacity(0.28)))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
            }
            .foregroundStyle(.white)

            Text("Can't decide? Swipe to find tonight's pick.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
    }

    /// A little swipe-card stack with a heart — a visual nod to the
    /// swipe-to-match mechanic the banner opens into.
    private var miniDeck: some View {
        ZStack {
            miniCard(rotation: -14, dx: -11, fill: .white.opacity(0.22))
            miniCard(rotation: 9,  dx: 9,  fill: .white.opacity(0.34))
            miniCard(rotation: -2, dx: 0,  fill: .white)
                .overlay {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
        }
        .frame(width: 56, height: 58)
    }

    private func miniCard(rotation: Double, dx: CGFloat, fill: Color) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(fill)
            .frame(width: 32, height: 46)
            .rotationEffect(.degrees(rotation))
            .offset(x: dx)
    }

    private var gradient: some View {
        ZStack {
            // Accent hue only — a light→dark sweep gives depth without
            // introducing an off-brand colour.
            LinearGradient(
                colors: [Color.accentColor.mix(with: .white, by: 0.12),
                         Color.accentColor.mix(with: .black, by: 0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // Soft light source in the top-left for depth.
            RadialGradient(
                colors: [.white.opacity(0.28), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 170
            )
        }
    }

    /// Diagonal highlight band that sweeps across the card.
    private var shine: some View {
        GeometryReader { geo in
            let w = geo.size.width
            LinearGradient(
                colors: [.clear, .white.opacity(0.12), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: w * 0.28)
            .rotationEffect(.degrees(22))
            // Wider travel than the card → the band spends longer off-screen,
            // so the wave reads as an occasional gentle glint, not a constant
            // sweep.
            .offset(x: shimmer * w * 1.8)
            .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
    }
}

/// Gentle press-scale used by tappable card surfaces.
private struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
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
                            heroPill(name: name)
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

    /// Display-only genre tag on the home-feed hero image. On iOS 26
    /// uses liquid glass; pre-iOS 26 uses `.ultraThinMaterial`.
    @ViewBuilder
    private func heroPill(name: String) -> some View {
        if #available(iOS 26.0, *) {
            Text(name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .glassEffect(.regular, in: Capsule())
        } else {
            Text(name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }
}
