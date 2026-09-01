//
//  SearchStartView.swift
//  Watchnow
//
//  Created by k.christopoulos on 31/8/26.
//

import SwiftUI

/// The screen behind the search field before anything has been typed.
///
/// The previous version was a static welcome card plus three "Movies /
/// Series / Actors" tiles that were styled exactly like buttons but were
/// deliberately inert — a tap target that looks tappable and isn't is the
/// one affordance mistake users reliably notice. It also meant a brand new
/// user landed on a screen with nothing to do but type.
///
/// This version keeps the welcome copy but demotes it to a header that
/// collapses out of the way the moment the field takes focus, and spends
/// the reclaimed space on things the user can actually act on: their
/// recent queries, and a live trending row that is a real shortcut into
/// content. Every animation here is gated behind Reduce Motion.
struct SearchStartView: View {

    @ObservedObject var viewModel: SearchViewModel
    /// True when the navigation bar is hidden and the band reaches the top
    /// of the display. Owned by `SearchView`, which decides that — see
    /// `SearchChromeModifier`.
    var bleedsUnderStatusBar: Bool = false
    /// Drives the hero collapse. Owned by `SearchView` because the focus
    /// state belongs to the `.searchable` field, not to this subtree.
    let isSearchFieldFocused: Bool
    /// Runs a search straight away, bypassing the keystroke debounce — a
    /// tap on a recent chip is an explicit, complete query, so making the
    /// user wait 0.6s for it would read as lag.
    let onSelectQuery: (String) -> Void
    /// Runs a genre browse. Kept separate from `onSelectQuery` because a
    /// genre isn't text: pushing "Horror" into the search field would run
    /// a title match on the word rather than the Discover query the chip
    /// promises, and would pollute recent searches with it.
    let onSelectGenre: (SearchModel.Genre) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var scopeNamespace
    /// Flipped on in `.onAppear` so the entrance animations have a state
    /// change to key off. Starting at `false` and animating to `true` is
    /// the only way to stagger an appearance in SwiftUI without a
    /// per-element timer.
    @State private var appeared = false
    /// Matches `TrendingPosterCard`'s own scaled height so the shelf's fixed
    /// row frame grows with the text inside it instead of cropping it.
    @ScaledMetric(relativeTo: .caption)
    private var trendingTextBox: CGFloat = TrendingPosterCard.textHeight

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                hero

                if !viewModel.recentSearches.isEmpty {
                    recentSection
                }

                genreSection

                trendingSection
            }
            .padding(.bottom, 32)
        }
        // Runs the band to the physical top of the display rather than
        // stopping at the status bar.
        //
        // Only where the navigation bar is already hidden — with a bar and a
        // search field up there the art would sit behind both, which is the
        // one thing this hero has always refused to do. The status bar itself
        // is different: its glyphs are small, high-contrast and system-drawn,
        // and iOS 26's soft scroll-edge effect (applied to this tab in
        // `ContentView`) keeps them legible as content passes under, without
        // the app painting anything over the artwork.
        .bleedingSafeArea(bleedsUnderStatusBar, edges: .top)
        .scrollDismissesKeyboard(.interactively)
        .onAppear { appeared = true }
        .task { await viewModel.loadTrendingIfNeeded() }
    }

    // MARK: - Motion helpers

    /// Returns `nil` under Reduce Motion, which makes every `.animation()`
    /// call site a no-op without an `if` around each one.
    private func motion(_ animation: Animation) -> Animation? {
        reduceMotion ? nil : animation
    }

    private var trendingRowHeight: CGFloat {
        TrendingPosterCard.posterHeight + 7 + trendingTextBox
    }

    /// Titles the hint chip draws from.
    ///
    /// Filtered by length: the chip is capped at the screen width, so a
    /// long title truncates to an ellipsis part-way through typing, which
    /// puts "Brand New D…" on screen where the caret should be and breaks
    /// the whole effect. Short titles are also simply better suggestions —
    /// they're the ones a person would actually type. Falls back to the
    /// unfiltered list on the rare day when nothing trending is short.
    var hintTitles: [String] {
        let all = viewModel.trendingMovies.map { $0.getResultTitle() }
        let short = all.filter { $0.count <= 22 }
        return Array((short.isEmpty ? all : short).prefix(6))
    }

    /// Per-item entrance delay, capped so a long row's tail doesn't arrive
    /// noticeably after the user has already started scrolling it.
    private func stagger(_ index: Int) -> Double {
        reduceMotion ? 0 : min(Double(index) * 0.05, 0.4)
    }

    /// Standard entrance: fade up from slightly below. Applied to each
    /// top-level block and to each item inside the two rows.
    private func entrance(_ index: Int) -> some ViewModifier {
        EntranceModifier(appeared: appeared,
                         animation: motion(.spring(response: 0.55, dampingFraction: 0.85)
                             .delay(stagger(index))))
    }
}

// MARK: - Hero

private extension SearchStartView {

    /// Cinematic header: two tilted rows of poster art drifting past each
    /// other behind the headline.
    ///
    /// This slot started as a 92pt magnifying-glass disc — an icon whose
    /// entire message was "this is the search screen", on the search
    /// screen. It's now built from the same trending art the shelf below
    /// uses, which says what's searchable by showing it, and keeps moving
    /// so the screen has a pulse before the user has typed anything.
    ///
    /// Deliberately *not* bled under the navigation bar: running poster
    /// art behind the title and the search field left both of them sitting
    /// on busy, uncontrollable colour, and a search field you can't read
    /// the placeholder in is a bad trade for a taller image.
    var hero: some View {
        ZStack(alignment: .bottom) {
            artBand

            VStack(spacing: 10) {
                Text("Find what to watch")
                    .appFont(28, weight: .bold, relativeTo: .title)
                    .foregroundStyle(.primary)
                    // Two shadows in the page colour rather than one, and
                    // both opaque: a wide soft pass to lift the text off
                    // whatever poster is behind it, and a tight pass to
                    // keep the letterforms crisp. Doing the separation
                    // locally leaves the band-wide gradient free to stay
                    // gentle — pushing *that* hard enough to ground the
                    // headline was washing out the artwork 150pt above it.
                    .shadow(color: Color(.background), radius: 14)
                    .shadow(color: Color(.background), radius: 5)

                HintChip(titles: hintTitles,
                         reduceMotion: reduceMotion,
                         onSelect: onSelectQuery)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4)
        }
        .frame(height: heroHeight)
        .frame(maxWidth: .infinity)
        .scaleEffect(isSearchFieldFocused ? 0.94 : 1, anchor: .top)
        .opacity(isSearchFieldFocused ? 0 : 1)
        .frame(height: isSearchFieldFocused ? 0 : nil, alignment: .top)
        // Clipped only while collapsing. The band needs to draw *above* its
        // own frame for the overscroll stretch, so an unconditional clip
        // here would swallow the effect.
        .clipped(isSearchFieldFocused)
        .accessibilityHidden(isSearchFieldFocused)
        .animation(motion(.spring(response: 0.42, dampingFraction: 0.85)),
                   value: isSearchFieldFocused)
        .modifier(entrance(0))
    }

    /// The artwork half of the header: drifting posters, the fades that
    /// blend them into the page, and the status-bar scrim.
    ///
    /// Split from the headline so the overscroll stretch can apply to the
    /// art alone. `MenuFeaturedView` stretches its whole hero, copy
    /// included, but that hero is a single still image with one line of
    /// title over it — here a `.bottom`-anchored scale of up to 1.4× would
    /// haul a 28pt headline and a text-filled pill up with it.
    ///
    /// `.clipped()` before `.stretchy()` is the order that matters: the
    /// band trims its own overflow first, then the *trimmed* band is scaled,
    /// so the growth escapes into the gap the rubber band opens above it
    /// instead of being cut off at the band's edge.
    ///
    /// The earlier note here said `.stretchy()` was unusable because the
    /// scroll geometry reports a large `minY` for a beat on tab re-entry and
    /// the band came back magnified. That was a real bug and it is fixed at
    /// the source — `StretchEffectModifier` now clamps the offset to one
    /// band-height — so the effect is back.
    var artBand: some View {
        HeroMarquee(rowOne: marqueeRowOne,
                    rowTwo: marqueeRowTwo,
                    rowThree: marqueeRowThree,
                    reduceMotion: reduceMotion)
            // Cropped to the band first, so the fade below is measured
            // against the band's own bounds rather than the marquee's taller
            // intrinsic height.
            .frame(height: heroHeight)
            .clipped()
            // Bottom fade only.
            //
            // There were two tinted layers over the top of this band — a
            // feather on the clip and a near-opaque scrim across the status
            // bar — and between them they spent the first third of a 340pt
            // band painting page colour over poster art. The band exists to
            // be a window onto artwork; a window with a curtain over the top
            // third is a smaller window. Both are gone.
            .overlay { bottomFade }
            .stretchy()
    }

    /// Fades the art out into the page so the band has no hard bottom edge,
    /// and gives the headline a solid ground to sit on.
    var bottomFade: some View {
        LinearGradient(stops: bottomFadeStops,
                       startPoint: .top,
                       endPoint: .bottom)
            .allowsHitTesting(false)
    }

    /// Sized from the bottom up: the headline and the hint chip need
    /// ~86pt between them, and the gradient needs roughly that much again
    /// above it to reach full opacity before the text starts. Tighter than
    /// this and the chip clips against the band's bottom edge.
    /// Taller when the band owns the top of the display, because it now
    /// starts behind the status bar rather than below it — the first ~59pt
    /// sit under the clock and the battery, so the extra height is what
    /// keeps a full window of art in clear view beneath them. Where the
    /// navigation bar is still present nothing eats the top and the band
    /// keeps its original size.
    var heroHeight: CGFloat { bleedsUnderStatusBar ? 340 : 238 }

    /// Fades the art out into the page so the band has no hard bottom edge
    /// and the headline has solid ground.
    ///
    /// Starts noticeably later on the taller band. The proportions that
    /// suited a 238pt band began dimming the art 60pt in, which on a 360pt
    /// band meant it was fading almost as soon as the top scrim let go.
    var bottomFadeStops: [Gradient.Stop] {
        let page = Color(.background)
        guard bleedsUnderStatusBar else {
            return [
                .init(color: page.opacity(0.00), location: 0.00),
                .init(color: page.opacity(0.05), location: 0.26),
                .init(color: page.opacity(0.20), location: 0.44),
                .init(color: page.opacity(0.50), location: 0.57),
                .init(color: page.opacity(0.80), location: 0.67),
                .init(color: page.opacity(0.96), location: 0.77),
                .init(color: page,               location: 0.85),
                .init(color: page,               location: 1.00),
            ]
        }
        // Reaches near-solid by ~0.80, which is where the headline block
        // starts. With three rows of art now filling the band edge to edge
        // there is always a poster behind that text, so it needs real
        // ground rather than the thin wash that sufficed when the lower
        // half of the band was mostly empty.
        return [
            .init(color: page.opacity(0.00), location: 0.00),
            .init(color: page.opacity(0.05), location: 0.31),
            .init(color: page.opacity(0.22), location: 0.45),
            .init(color: page.opacity(0.50), location: 0.57),
            .init(color: page.opacity(0.79), location: 0.68),
            .init(color: page.opacity(0.95), location: 0.78),
            // Solid well before the band's bottom edge, so the clip lands
            // on flat background instead of cutting a poster in half.
            .init(color: page,               location: 0.86),
            .init(color: page,               location: 1.00),
        ]
    }

    /// Top drift row: trending movies.
    var marqueeRowOne: [URL] {
        viewModel.trendingMovies.prefix(6).map { $0.getPosterURL() }
    }

    /// Middle drift row: trending series, so neighbouring rows never show
    /// the same poster passing itself in opposite directions.
    var marqueeRowTwo: [URL] {
        viewModel.trendingSeries.prefix(6).map { $0.getPosterURL() }
    }

    /// Bottom drift row: further down the movie feed, so it repeats
    /// neither of the rows above it. Short slices are fine — `DriftRow`
    /// tiles whatever it's given up to a full screen width.
    var marqueeRowThree: [URL] {
        viewModel.trendingMovies.dropFirst(3).prefix(6).map { $0.getPosterURL() }
    }
}

// MARK: - Recent searches

private extension SearchStartView {

    var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionLabel("Recent", icon: "clock.fill")
                Spacer(minLength: 0)
                Button("Clear All") {
                    withAnimation(motion(.spring(response: 0.35, dampingFraction: 0.85))) {
                        viewModel.clearRecentSearches()
                    }
                }
                .appFont(13, weight: .medium, relativeTo: .footnote)
                .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 16)

            FlowLayout(spacing: 8) {
                ForEach(Array(viewModel.recentSearches.enumerated()), id: \.element) { index, query in
                    RecentSearchChip(query: query) {
                        onSelectQuery(query)
                    } onRemove: {
                        withAnimation(motion(.spring(response: 0.35, dampingFraction: 0.8))) {
                            viewModel.removeRecentSearch(query)
                        }
                    }
                    .modifier(entrance(index + 1))
                }
            }
            .padding(.horizontal, 16)
        }
        .modifier(entrance(1))
    }
}

// MARK: - Browse by genre

private extension SearchStartView {

    /// Genre chips — the "I don't know the title, I know the mood" path.
    ///
    /// Search previously had exactly one way in: know a name and type it.
    /// That's the wrong shape for the most common question this app gets
    /// asked ("what horror is worth watching?"), and the Discover endpoint
    /// behind these chips was already in the project for Movie Night.
    ///
    /// Wrapped rather than horizontally scrolled: every genre is equally
    /// likely to be the one you want, so hiding two thirds of them off the
    /// right edge would bias the choice toward whatever happened to be
    /// alphabetically early.
    var genreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Browse by genre", icon: "square.grid.2x2.fill")
                .padding(.horizontal, 16)

            FlowLayout(spacing: 8) {
                ForEach(Array(SearchModel.Genre.browsable.enumerated()), id: \.element) { index, genre in
                    GenreBrowseChip(genre: genre) {
                        onSelectGenre(genre)
                    }
                    .modifier(entrance(index + 2))
                }
            }
            .padding(.horizontal, 16)
        }
        .modifier(entrance(2))
    }
}

// MARK: - Trending

private extension SearchStartView {

    /// Live trending feed — the reason this screen is worth landing on.
    /// Header, a Movies / TV Series scope toggle, then a horizontal poster
    /// row. Both feeds are fetched together, so the toggle switches with no
    /// network wait.
    var trendingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                sectionLabel("Trending today",
                             icon: "flame.fill",
                             tint: .orange,
                             pulses: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)

            scopeToggle

            trendingContent
        }
        .modifier(entrance(3))
        // The shelf is a fixed-height row of covers; past the first
        // accessibility size the titles under them stop fitting beside the
        // artwork. Each cover still opens an unclamped details screen.
        .artworkTypeClamp()
    }

    /// Two-pill segmented control. The selected fill is a single capsule
    /// moved between pills with `matchedGeometryEffect`, so the highlight
    /// slides across instead of blinking off one pill and on to the other —
    /// same grammar as the season tabs on the details screen.
    var scopeToggle: some View {
        HStack(spacing: 6) {
            ForEach(SearchModel.TrendingScope.allCases) { scope in
                scopePill(scope)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .sensoryFeedback(.selection, trigger: viewModel.trendingScope)
    }

    @ViewBuilder
    func scopePill(_ scope: SearchModel.TrendingScope) -> some View {
        let isSelected = viewModel.trendingScope == scope

        Button {
            withAnimation(motion(.spring(response: 0.34, dampingFraction: 0.78))) {
                viewModel.trendingScope = scope
            }
        } label: {
            Text(scope.title)
                .appFont(13, weight: .semibold, relativeTo: .footnote)
                .foregroundStyle(isSelected ? .white : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(Color.accentColor)
                            .matchedGeometryEffect(id: "trendingScopePill", in: scopeNamespace)
                    } else {
                        Capsule(style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    }
                }
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Trending \(scope.title)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// Skeleton → row → error, cross-faded. `hasTrending` (not
    /// `isLoadingTrending`) picks the branch so a retry after a partial
    /// success never yanks loaded posters back to a skeleton.
    @ViewBuilder
    var trendingContent: some View {
        if viewModel.hasTrending {
            trendingRow
                .transition(.opacity)
        } else if viewModel.trendingFailed {
            trendingErrorRow
                .transition(.opacity)
        } else {
            TrendingSkeletonRow()
                .transition(.opacity)
        }
    }

    var trendingRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(Array(viewModel.trending.prefix(20).enumerated()), id: \.element) { index, result in
                    TrendingPosterCard(result: result,
                                       screenType: viewModel.trendingScope.screenType,
                                       reduceMotion: reduceMotion)
                        .modifier(entrance(index + 2))
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: trendingRowHeight)
        // Without this the row can come up already scrolled a card or two
        // in: the skeleton it replaces is a different width, and SwiftUI
        // preserves the *proportional* offset across the swap rather than
        // resetting it.
        .defaultScrollAnchor(.leading)
        // Re-runs the row's entrance as a soft cross-fade when the scope
        // flips, so the swap reads as new content arriving rather than the
        // same shelf silently re-labelled.
        .id(viewModel.trendingScope)
        .transition(.opacity.combined(with: .offset(y: 8)))
        .animation(motion(.easeOut(duration: AppMotion.standard)), value: viewModel.trendingScope)
    }

    /// Inline, row-shaped failure. Deliberately not a full-screen
    /// `ContentUnavailableView` — trending is a bonus shelf, and a failed
    /// bonus shouldn't take the recents block down with it.
    var trendingErrorRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Couldn't load trending titles.")
                .appFont(14, relativeTo: .subheadline)
                .foregroundStyle(.secondary)
            Button {
                Task { await viewModel.loadTrending() }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .appFont(13, weight: .semibold, relativeTo: .footnote)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.accentColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }

    /// Small tinted-icon + title pair. Intentionally *not* `SectionHeaderView`
    /// — that component's 25pt heavy title is sized to head a full feed and
    /// would out-shout the "Search" navigation title one line above it.
    func sectionLabel(_ title: String,
                      icon: String,
                      tint: Color = .secondary,
                      pulses: Bool = false) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .appFont(13, weight: .semibold, relativeTo: .footnote)
                .foregroundStyle(tint)
                .symbolRenderingMode(.hierarchical)
                // Marks the shelf as a live feed rather than a fixed
                // editorial list — the same signal `SectionHeaderView`
                // sends with its `PulseDot` on the home tabs.
                .symbolEffect(.pulse, options: reduceMotion ? .nonRepeating : .repeating,
                              isActive: pulses)
            Text(title)
                .appFont(14, weight: .semibold, relativeTo: .subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

// MARK: - EntranceModifier

/// Fade-and-rise entrance shared by every block on this screen. Extracted
/// into a modifier so the three-line opacity/offset/animation trio isn't
/// repeated at each call site.
private struct EntranceModifier: ViewModifier {
    let appeared: Bool
    let animation: Animation?

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
            .animation(animation, value: appeared)
    }
}

