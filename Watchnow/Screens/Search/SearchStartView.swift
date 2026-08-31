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
    /// What the hint is currently showing — a growing or shrinking prefix
    /// of `hintTarget` while the typewriter runs, or the whole title once
    /// it's finished typing.
    @State private var typedHint = ""
    /// The full title behind `typedHint`. Kept separate so a tap during
    /// the typing animation searches the whole title rather than whatever
    /// half of it happens to be on screen.
    @State private var hintTarget: String?

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
        .scrollDismissesKeyboard(.interactively)
        .onAppear { appeared = true }
        .task { await viewModel.loadTrendingIfNeeded() }
        .task { await runHints() }
    }

    // MARK: - Motion helpers

    /// Returns `nil` under Reduce Motion, which makes every `.animation()`
    /// call site a no-op without an `if` around each one.
    private func motion(_ animation: Animation) -> Animation? {
        reduceMotion ? nil : animation
    }

    /// Types each trending title out a character at a time, holds it, then
    /// backspaces it away before starting the next one.
    ///
    /// A `Task` loop rather than a `Timer`: it's cancelled automatically
    /// when the view goes away, so backing out of search doesn't leave a
    /// timer ticking against a detached view.
    ///
    /// Under Reduce Motion the titles still rotate — the suggestion is
    /// useful information, not decoration — but they swap whole rather
    /// than animating in letter by letter. Text that rewrites itself
    /// thirty times a second is exactly what that setting is asking us to
    /// stop doing.
    func runHints() async {
        while !Task.isCancelled {
            let titles = hintTitles

            guard !titles.isEmpty else {
                // Trending hasn't landed — or the fetch failed outright, in
                // which case this waits for the rest of the view's life.
                // Slow enough that the standing case costs nothing, quick
                // enough that the normal case starts typing right after the
                // feed arrives.
                try? await Task.sleep(for: .seconds(1))
                continue
            }

            for title in titles {
                guard !Task.isCancelled else { return }
                hintTarget = title

                if reduceMotion {
                    typedHint = title
                    try? await Task.sleep(for: .seconds(3.4))
                    continue
                }

                await type(title)
                try? await Task.sleep(for: .seconds(1.9))
                await backspace(title)

                // `hintTarget` deliberately outlives the text it typed. It
                // gates the chip against the fallback description, so
                // clearing it here dropped the whole pill for the length of
                // the gap and flashed "Movies, series and the people who
                // make them." in its place between every title. Holding it
                // also means a tap landing in the gap searches the title
                // the user just watched finish, rather than nothing.
                //
                // Beat on the empty caret before the next title starts, so
                // the two runs read as separate words rather than one
                // continuous scramble.
                try? await Task.sleep(for: .milliseconds(280))
            }
        }
    }

    /// Titles the typewriter draws from.
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

    /// Reveals `title` one character at a time.
    func type(_ title: String) async {
        for index in 1...max(title.count, 1) {
            guard !Task.isCancelled else { return }
            typedHint = String(title.prefix(index))
            try? await Task.sleep(for: .milliseconds(42))
        }
    }

    /// Removes `title` one character at a time. Faster than typing —
    /// deleting is the part nobody's reading, and matching the two speeds
    /// makes the whole cycle feel twice as long as it is.
    func backspace(_ title: String) async {
        guard title.count > 0 else { return }
        for index in stride(from: title.count - 1, through: 0, by: -1) {
            guard !Task.isCancelled else { return }
            typedHint = String(title.prefix(index))
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    /// Per-item entrance delay, capped so a long row's tail doesn't arrive    /// Per-item entrance delay, capped so a long row's tail doesn't arrive
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
            HeroMarquee(rowOne: marqueeRowOne,
                        rowTwo: marqueeRowTwo,
                        rowThree: marqueeRowThree,
                        reduceMotion: reduceMotion)
                // No `.stretchy()` here, deliberately. That modifier scales
                // by `frame(in: .scrollView).minY` from a `.bottom` anchor,
                // and on returning to this tab the scroll geometry reports a
                // large minY for a beat before it settles. The band came
                // back magnified and pinned to its lower edge — blank at the
                // top, posters far too big — and only looked right once the
                // offset resolved a second later. The two counter-drifting
                // rows already give this header its motion; a rubber band
                // isn't worth a header that renders wrong every time you
                // open the tab.
                //
                // Feathers the top edge. Applied here rather than inside
                // the marquee because the fade has to be measured against
                // the band's own bounds — that's the edge that clips, and
                // the marquee's intrinsic height doesn't match it.
                .frame(height: heroHeight)
                .clipped()
                .mask {
                    LinearGradient(stops: [
                        .init(color: .clear,              location: 0.00),
                        .init(color: .black.opacity(0.5), location: maskFeather * 0.4),
                        .init(color: .black,              location: maskFeather),
                        .init(color: .black,              location: 1.00),
                    ], startPoint: .top, endPoint: .bottom)
                }

            // Fades the art out into the page so the band has no hard
            // bottom edge, and gives the headline a solid ground to sit on.
            LinearGradient(stops: bottomFadeStops,
                           startPoint: .top,
                           endPoint: .bottom)
                .allowsHitTesting(false)

            if bleedsUnderStatusBar {
                statusBarScrim
            }

            VStack(spacing: 10) {
                Text("Find what to watch")
                    .font(.system(size: 28, weight: .bold))
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

                hintChip
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4)
        }
        .frame(height: heroHeight)
        .frame(maxWidth: .infinity)
        .clipped()
        .scaleEffect(isSearchFieldFocused ? 0.94 : 1, anchor: .top)
        .opacity(isSearchFieldFocused ? 0 : 1)
        .frame(height: isSearchFieldFocused ? 0 : nil, alignment: .top)
        .clipped()
        .accessibilityHidden(isSearchFieldFocused)
        .animation(motion(.spring(response: 0.42, dampingFraction: 0.85)),
                   value: isSearchFieldFocused)
        .modifier(entrance(0))
    }

    /// Sized from the bottom up: the headline and the hint chip need
    /// ~86pt between them, and the gradient needs roughly that much again
    /// above it to reach full opacity before the text starts. Tighter than
    /// this and the chip clips against the band's bottom edge.
    /// Taller when the band owns the top of the display: the scrim over
    /// the status bar consumes the first ~110pt, so without the extra
    /// height there was barely 60pt of unobscured art between it and the
    /// bottom fade — which is what made the band read as a sliced-off
    /// sliver rather than a window onto artwork. Where the navigation bar
    /// is still present nothing eats the top and the band keeps its
    /// original size.
    var heroHeight: CGFloat { bleedsUnderStatusBar ? 340 : 238 }

    /// How far down the band its own top clip is feathered.
    ///
    /// Barely any when the status-bar scrim is present — that gradient
    /// already hides the art up there, and stacking a second fade on top
    /// of it left the top third blank and then produced art abruptly, the
    /// hard horizontal line this was meant to avoid. Longer when there's
    /// no scrim, where this is the only thing softening the clip.
    var maskFeather: CGFloat { bleedsUnderStatusBar ? 0.05 : 0.26 }

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

    /// Softens the art directly under the status bar.
    ///
    /// With the navigation bar hidden the band reaches the top of the
    /// display, which puts the clock and the battery on top of whatever
    /// poster happens to be drifting past — black glyphs on a bright red
    /// one-sheet is not a readable combination, and unlike the app's own
    /// text these aren't ours to restyle. iOS 26's soft scroll-edge effect
    /// helps, but it's tuned for content scrolling *under* a bar rather
    /// than content resting at the top, so it doesn't go far enough alone.
    ///
    /// Fades to the page colour rather than to black so it stays correct
    /// in both appearances: the status bar's glyphs invert with the system
    /// theme, and so does `Color(.background)`.
    var statusBarScrim: some View {
        VStack(spacing: 0) {
            LinearGradient(stops: [
                .init(color: Color(.background).opacity(0.96), location: 0.00),
                .init(color: Color(.background).opacity(0.88), location: 0.55),
                .init(color: Color(.background).opacity(0.62), location: 0.72),
                .init(color: Color(.background).opacity(0.30), location: 0.86),
                .init(color: Color(.background).opacity(0.00), location: 1.00),
            ], startPoint: .top, endPoint: .bottom)
            // Holds near-opaque across the status bar's own height (~59pt
            // of these 96), then releases. Shaped as hold-then-ramp rather
            // than a straight line so the clock stays legible without
            // spending the whole gradient dimming artwork nobody is
            // reading over.
            .frame(height: 96)

            Spacer(minLength: 0)
        }
        .allowsHitTesting(false)
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

    /// The rotating suggestion, typed out as a real control.
    ///
    /// The title types itself in, holds, then backspaces away before the
    /// next one starts — the chip is the caret's field. It stays tappable
    /// throughout and always searches `hintTarget`, the *whole* title, so
    /// a tap landing mid-animation never runs a half-typed query.
    ///
    /// Falls back to a plain description before trending arrives, so the
    /// line is never an empty pill.
    @ViewBuilder
    var hintChip: some View {
        if hintTarget != nil || !typedHint.isEmpty {
            Button {
                if let hintTarget { onSelectQuery(hintTarget) }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))

                    HStack(spacing: 1) {
                        Text(typedHint)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        if !reduceMotion {
                            BlinkingCaret()
                        }
                    }
                }
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                // Floor on the width so the pill doesn't collapse to a
                // stub between titles, and no implicit animation on the
                // resize — a capsule easing out one character-width at a
                // time lags behind the text and reads as a wobble.
                .frame(minWidth: 150)
                .animation(nil, value: typedHint)
                .background {
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                }
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.30), lineWidth: 0.5)
                }
                .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(GenreChipPressStyle(reduceMotion: reduceMotion))
            .accessibilityLabel(hintTarget.map { "Search for \($0)" } ?? "Suggestion")
            .frame(height: 38)
        } else {
            Text("Movies, series and the people who make them.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .transition(.opacity)
                .frame(height: 38)
        }
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
                .font(.system(size: 13, weight: .medium))
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
                .font(.system(size: 13, weight: .semibold))
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
        .frame(height: TrendingPosterCard.totalHeight)
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
        .animation(motion(.easeOut(duration: 0.28)), value: viewModel.trendingScope)
    }

    /// Inline, row-shaped failure. Deliberately not a full-screen
    /// `ContentUnavailableView` — trending is a bonus shelf, and a failed
    /// bonus shouldn't take the recents block down with it.
    var trendingErrorRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Couldn't load trending titles.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Button {
                Task { await viewModel.loadTrending() }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
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
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .symbolRenderingMode(.hierarchical)
                // Marks the shelf as a live feed rather than a fixed
                // editorial list — the same signal `SectionHeaderView`
                // sends with its `PulseDot` on the home tabs.
                .symbolEffect(.pulse, options: reduceMotion ? .nonRepeating : .repeating,
                              isActive: pulses)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
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

