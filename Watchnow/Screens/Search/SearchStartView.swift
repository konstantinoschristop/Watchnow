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
                        reduceMotion: reduceMotion)
                // Grows with an overscroll pull, the same way the home
                // tabs' hero does. Applied to the art alone — stretching
                // the whole band would scale the headline with it.
                .stretchy()
                // Feathers the top edge. Applied here rather than inside
                // the marquee because the fade has to be measured against
                // the band's own bounds — that's the edge that clips, and
                // the marquee's intrinsic height doesn't match it.
                .frame(height: Self.heroHeight)
                .clipped()
                .mask {
                    LinearGradient(stops: [
                        .init(color: .clear,              location: 0.00),
                        .init(color: .black.opacity(0.5), location: 0.10),
                        .init(color: .black,              location: 0.26),
                        .init(color: .black,              location: 1.00),
                    ], startPoint: .top, endPoint: .bottom)
                }

            // Fades the art out into the page so the band has no hard
            // bottom edge, and gives the headline a solid ground to sit on.
            LinearGradient(stops: [
                .init(color: Color(.background).opacity(0.00), location: 0.00),
                .init(color: Color(.background).opacity(0.05), location: 0.26),
                .init(color: Color(.background).opacity(0.20), location: 0.44),
                .init(color: Color(.background).opacity(0.50), location: 0.57),
                .init(color: Color(.background).opacity(0.80), location: 0.67),
                .init(color: Color(.background).opacity(0.96), location: 0.77),
                // Solid well before the band's bottom edge, so the clip
                // lands on flat background instead of cutting a poster in
                // half.
                .init(color: Color(.background),               location: 0.85),
                .init(color: Color(.background),               location: 1.00),
            ], startPoint: .top, endPoint: .bottom)
            .allowsHitTesting(false)

            VStack(spacing: 10) {
                Text("Find what to watch")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                    .shadow(color: Color(.background).opacity(0.6), radius: 6)

                hintChip
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4)
        }
        .frame(height: Self.heroHeight)
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
    static var heroHeight: CGFloat { 238 }

    /// Top drift row: trending movies.
    var marqueeRowOne: [URL] {
        viewModel.trendingMovies.prefix(6).map { $0.getPosterURL() }
    }

    /// Bottom drift row: trending series, so the two rows never show the
    /// same poster passing itself in opposite directions.
    var marqueeRowTwo: [URL] {
        viewModel.trendingSeries.prefix(6).map { $0.getPosterURL() }
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

// MARK: - BlinkingCaret

/// Text cursor for the typed hint.
///
/// Its own view with its own `@State` on purpose: the parent re-renders on
/// every keystroke of the typewriter, and an animation started in the
/// parent would be torn down and restarted forty times a second. Nothing
/// here depends on the typed text, so SwiftUI leaves the blink alone.
private struct BlinkingCaret: View {
    @State private var dim = false

    var body: some View {
        RoundedRectangle(cornerRadius: 0.5, style: .continuous)
            .frame(width: 1.5, height: 15)
            .foregroundStyle(Color.accentColor)
            .opacity(dim ? 0 : 1)
            .onAppear {
                withAnimation(.linear(duration: 0.55).repeatForever(autoreverses: true)) {
                    dim = true
                }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - HeroMarquee

/// Two rows of poster art, tilted off-axis and drifting past each other in
/// opposite directions.
///
/// Counter-drift rather than two rows going the same way: parallel motion
/// reads as one sliding sheet, while opposed motion reads as depth, and
/// it's what stops a slow drift from looking like a stuck carousel. The
/// pair is rotated and over-scaled so neither the tilt nor the wrap seam
/// ever exposes a corner of the band.
private struct HeroMarquee: View {
    let rowOne: [URL]
    let rowTwo: [URL]
    let reduceMotion: Bool

    private let tilt: Double = -11
    private let overscale: CGFloat = 1.45

    var body: some View {
        VStack(spacing: 8) {
            DriftRow(posters: rowOne, reversed: false, speed: 13, reduceMotion: reduceMotion)
            DriftRow(posters: rowTwo, reversed: true,  speed: 10, reduceMotion: reduceMotion)
        }
        .rotationEffect(.degrees(tilt))
        // Both are render transforms, so the rows still lay out at the
        // band's own width — the tilt costs nothing in layout terms.
        .scaleEffect(overscale)
        // A whisper of blur — enough to keep the art from competing with
        // the headline for focus, not enough to read as out-of-focus. The
        // legibility work is done by the scrim in `hero`, so the art
        // itself stays at full strength; dropping its opacity instead
        // washed it out to grey against the light background.
        .blur(radius: 0.3)
        .frame(maxWidth: .infinity)
        .clipped()
        .accessibilityHidden(true)
    }
}

// MARK: - DriftRow

/// One endlessly drifting row of poster art.
///
/// Driven by a single `.repeatForever` animation on one `offset` rather
/// than a per-frame `TimelineView`: the timeline approach would rebuild a
/// dozen `KFImage`s sixty times a second, while animating one offset hands
/// the whole thing to the render server and costs nothing per frame. The
/// row is duplicated end to end and travels exactly one copy's width, so
/// the wrap is seamless.
private struct DriftRow: View {
    let posters: [URL]
    /// `true` sends this row right instead of left.
    let reversed: Bool
    /// Points per second. Slow enough to read as ambience rather than as a
    /// carousel the user is expected to track.
    let speed: CGFloat
    let reduceMotion: Bool

    @State private var offset: CGFloat = 0

    private let posterWidth: CGFloat = 80
    private let posterHeight: CGFloat = 120
    private let spacing: CGFloat = 8

    /// Width of one full copy — the exact distance to travel before the
    /// duplicate lines up with the original.
    private var loopWidth: CGFloat {
        CGFloat(posters.count) * (posterWidth + spacing)
    }

    var body: some View {
        // A disabled horizontal ScrollView, not a bare `.clipped()` frame.
        // `.clipped()` only trims what's *drawn* — the stack underneath
        // still reports its full width to the parent, which stretched the
        // enclosing VStack and dragged the genre grid and trending row
        // off-screen with it. A ScrollView reports the width it was
        // offered and keeps the overflow to itself.
        ScrollView(.horizontal, showsIndicators: false) {
            content
                .frame(height: posterHeight)
        }
        .scrollDisabled(true)
        .frame(height: posterHeight)
    }

    @ViewBuilder
    private var content: some View {
        if posters.isEmpty {
            placeholder
        } else {
            HStack(spacing: spacing) {
                ForEach(0..<(posters.count * 2), id: \.self) { index in
                    PosterImage(url: posters[index % posters.count],
                                width: posterWidth * 2,
                                height: posterHeight * 2,
                                cornerRadius: 9,
                                shadowRadius: 0)
                        .frame(width: posterWidth, height: posterHeight)
                        // Fill behind each poster so a slot that hasn't
                        // decoded yet reads as a card still loading rather
                        // than a hole punched in the strip.
                        .background {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Color(.tertiarySystemFill))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        // Hairline edge so neighbouring posters stay
                        // distinct where two dark ones meet.
                        .overlay {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
                        }
                }
            }
            .offset(x: reversed ? offset - loopWidth : -offset)
            .onAppear { startDrift() }
            .onChange(of: posters.count) { _, _ in startDrift() }
        }
    }

    private var placeholder: some View {
        InlineShimmerContainer {
            HStack(spacing: spacing) {
                ForEach(0..<7, id: \.self) { _ in
                    ShimmerBox(cornerRadius: 9)
                        .frame(width: posterWidth, height: posterHeight)
                }
            }
        }
    }

    /// Restarts the loop from zero. Called on appear and whenever the
    /// poster count changes, because `loopWidth` — and therefore the
    /// duration that makes the wrap seamless — depends on it.
    private func startDrift() {
        guard !reduceMotion, loopWidth > 0 else {
            offset = 0
            return
        }
        offset = 0
        withAnimation(.linear(duration: Double(loopWidth / speed))
            .repeatForever(autoreverses: false)) {
            offset = loopWidth
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

// MARK: - TrendingPosterCard

/// Compact poster tile for the trending row.
///
/// Narrower than the home feed's `BottomCard` (108pt vs 150pt) on purpose:
/// this shelf is a shortcut on a screen whose primary action is typing, so
/// it should read as a secondary offer and let four-and-a-bit posters peek
/// in, which is what signals "scrollable" without a chevron.
private struct TrendingPosterCard: View {
    let result: Result
    let screenType: ScreenTypes
    let reduceMotion: Bool

    @Namespace private var namespace
    @State private var isPressed = false

    static let posterWidth: CGFloat = 108
    static let posterHeight: CGFloat = 162
    /// Poster + spacing + two text lines. Pinned so the enclosing
    /// ScrollView has a fixed height and the sections below it don't shift
    /// as posters stream in.
    static let totalHeight: CGFloat = 218

    private let cornerRadius: CGFloat = 12

    var body: some View {
        NavigationLink {
            let model = ContentDetailsModel(screenType: screenType, result: result)
            let vm = ContentDetailsViewModel(model: model)
            ContentDetailsView(detailsViewModel: vm)
                .navigationTransition(.zoom(sourceID: result.id ?? 0, in: namespace))
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                poster
                title
                Spacer(minLength: 0)
            }
            .frame(width: Self.posterWidth, height: Self.totalHeight, alignment: .top)
        }
        .buttonStyle(PressableCardStyle(reduceMotion: reduceMotion))
        .matchedTransitionSource(id: result.id ?? 0, in: namespace)
        .accessibilityLabel(result.getResultTitle())
        .accessibilityHint("Opens details")
    }

    private var poster: some View {
        PosterImage(url: result.getPosterURL(),
                    width: Self.posterWidth * 2,
                    height: Self.posterHeight * 2,
                    cornerRadius: cornerRadius,
                    shadowRadius: 0)
            .frame(width: Self.posterWidth, height: Self.posterHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.30), radius: 5, y: 3)
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(result.getResultTitle())
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            let year = result.getReleaseDate(addSeparator: false)
            if !year.isEmpty {
                Text(year)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: Self.posterWidth, alignment: .leading)
    }
}

// MARK: - PressableCardStyle

/// Spring scale-down on press. Uses a `ButtonStyle` rather than a
/// `DragGesture` so it composes with `NavigationLink` without competing
/// with the scroll view's own gesture recognition.
private struct PressableCardStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}

// MARK: - TrendingSkeletonRow

/// Shimmer placeholder matching `TrendingPosterCard`'s exact geometry, so
/// the real posters land in place instead of nudging the layout when the
/// fetch returns.
private struct TrendingSkeletonRow: View {

    var body: some View {
        InlineShimmerContainer {
            // Same ScrollView wrapper as `trendingRow`, not a bare HStack.
            // A bare stack five cards wide overflows the screen and reports
            // that width up to the enclosing vertical ScrollView, which
            // knocked the whole start screen's layout sideways for a frame.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(0..<5, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 7) {
                            ShimmerBox(cornerRadius: 12)
                                .frame(width: TrendingPosterCard.posterWidth,
                                       height: TrendingPosterCard.posterHeight)
                            ShimmerBox(cornerRadius: 4)
                                .frame(width: TrendingPosterCard.posterWidth * 0.85, height: 10)
                            ShimmerBox(cornerRadius: 4)
                                .frame(width: TrendingPosterCard.posterWidth * 0.45, height: 9)
                            Spacer(minLength: 0)
                        }
                        .frame(width: TrendingPosterCard.posterWidth,
                               height: TrendingPosterCard.totalHeight, alignment: .top)
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollDisabled(true)
        }
        .frame(height: TrendingPosterCard.totalHeight, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - GenreBrowseChip

/// Icon + label pill for a browsable genre.
///
/// Tinted rather than neutral so the grid reads as a palette of choices
/// instead of a wall of identical grey pills — but tinted *quietly* (12%
/// fill, hierarchical icon), because unlike `FilterChip` none of these is
/// ever in a selected state on this screen: tapping one leaves for the
/// results list.
private struct GenreBrowseChip: View {
    let genre: SearchModel.Genre
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: genre.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                Text(genre.name)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.22), lineWidth: 0.5)
            }
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(GenreChipPressStyle(reduceMotion: reduceMotion))
        .accessibilityLabel("Browse \(genre.name)")
        .accessibilityHint("Shows popular \(genre.name.lowercased()) titles")
    }
}

/// Springy press for the genre chips. Scales further than
/// `ChipPressStyle` because a genre tap navigates away — the extra travel
/// is the acknowledgement that something is about to happen.
private struct GenreChipPressStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.93 : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.6),
                       value: configuration.isPressed)
    }
}

// MARK: - RecentSearchChip

/// Chip is split into two side-by-side tap zones so the X is reliably
/// hittable. The previous nested-button layout fought SwiftUI's hit
/// testing — the outer button's tap area swallowed touches near the X,
/// and the X's 3-pt padding gave it a tap target well below Apple's
/// 44-pt recommendation. Now both halves are sibling `Button`s sharing
/// a single Capsule background, each with explicit `contentShape` so
/// the entire half is tappable, not just the visible icon/text.
private struct RecentSearchChip: View {
    let query: String
    let onTap: () -> Void
    let onRemove: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                    Text(query)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .padding(.leading, 14)
                .padding(.trailing, 6)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(ChipPressStyle(reduceMotion: reduceMotion))
            .accessibilityLabel("Search \(query)")

            // Hairline separator clarifies that the X is its own tap
            // zone — without it the chip reads as one solid pill and
            // the user's finger lands on the text half by default.
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 0.5, height: 18)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 10)
                    .padding(.trailing, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ChipPressStyle(reduceMotion: reduceMotion))
            .accessibilityLabel("Remove \(query) from recent searches")
        }
        .background {
            Capsule(style: .continuous)
                .fill(Color(.secondarySystemBackground))
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
        }
        // Chips leave by shrinking into their own centre, so removing one
        // reads as it collapsing out of the flow rather than the whole row
        // re-flowing around a hole.
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }
}

/// Press treatment for the two halves of a recent chip. Scoped tighter
/// than `PressableCardStyle` — a chip is small enough that a 0.94 scale
/// reads as a wobble, so this only dips the opacity and eases the tint.
private struct ChipPressStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15),
                       value: configuration.isPressed)
    }
}

// MARK: - FlowLayout

/// A simple wrapping layout that flows chips into rows.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                height += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
