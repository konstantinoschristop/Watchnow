//
//  MenuFeaturedView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 13/6/23.
//

import SwiftUI
import Kingfisher
import CoreImage

/// The heroes on the Movies and Series tabs and a streaming service's
/// catalogue: their leading titles, one at a time.
///
/// A slide holds the title's best film still (`StillsArt`), under the
/// title's official logo. The art runs edge to edge under the status bar
/// and the title, meets the page at its foot (see `dissolvesIntoPage`), and
/// drifts at a third of the page's speed as it scrolls; pulled down, it
/// stretches. Titles change every six seconds or by a swipe, the art
/// blending from one into the next rather than sliding; the dots under the
/// copy count down to the next and pause all of it.
///
/// Laid out like a title card, centred: the badge, the logo large, one line
/// of facts, then Trailer and Watch Later. Under the copy the picture
/// darkens (`scrims`), so the copy always sits on shadow, whatever the
/// still behind it is.
///
/// Chosen over two other takes trialled side by side — the logo tucked
/// behind the poster's subject, and the copy on a Liquid Glass panel.
/// Shared metrics for the featured hero, so the view and whatever supplies
/// its overlay agree on the same numbers.
///
/// Its own namespace because `MenuFeaturedView` is generic over its overlay
/// content, and Swift allows no static stored properties there.
enum FeaturedHeroMetrics {

    /// How much of its container the hero takes. Three-quarters left the
    /// genre chips and Movie Night below the fold, and 0.6 left no room for
    /// a title card with actions under it; at this the hero leads the page
    /// and the genre chips still show beneath it. The loading skeleton
    /// reads it too, so the page doesn't jump when content lands.
    static let heightFraction: CGFloat = 0.7
}

struct MenuFeaturedView<Content: View>: View {
    var results: [Result]
    /// The copy for one slide: what it is, its title, meta and genres. Set
    /// in white over the hero's own scrims, so it brings no background.
    var overlayContent: (Result) -> Content
    let screenType: ScreenTypes
    /// When `true`, tapping a slide navigates to its details screen.
    var isTappable: Bool = true

    /// Height of the scroll container this hero sits in, when the caller can
    /// measure it. `containerRelativeFrame(.vertical)` resolves against a
    /// `ScrollView` but has nothing to resolve against inside a `List` row,
    /// where it collapses the hero to nothing — so the feed measures the
    /// container itself and hands the number down.
    var containerHeight: CGFloat? = nil

    /// The colour of the page under the hero, which on a light page meets
    /// the picture on a rounded edge (`pageEdge`) and has to match exactly.
    var pageColor: Color = Color(.background)

    /// Seconds each slide dwells before auto-advancing. A user swipe (or a
    /// scene-phase change) restarts this countdown from zero, so viewers
    /// always get a full window to read the slide they just landed on.
    private var slideDwell: Duration { .seconds(dwellSeconds) }
    /// How long each title stays before the next. Nine and a half seconds
    /// read as the hero being stuck.
    private let dwellSeconds: Double = 6

    /// The dissolve into the page at the hero's foot: long and eased, so
    /// there's no line where the picture stops. It was 72pt and nearly
    /// linear, which read as an edge with a blur on it.
    private let fadeHeight: CGFloat = 120
    /// How far up from the hero's foot the page dots sit, with the copy
    /// above them: about twenty points above the light page's edge
    /// (`pageEdge`), low enough that the dots close the hero rather than
    /// float in it.
    private let copyLift: CGFloat = 44

    @State private var scrollIndex: Int? = 0
    @State private var isDragging: Bool = false
    @State private var selectedResult: Result?
    /// Each slide's own colour, taken from its poster once it has loaded —
    /// the wash the picture dissolves into.
    @State private var slideTints: [Int: Color] = [:]
    /// Each slide's stills, textless poster and logo, by title id, once
    /// fetched.
    @State private var arts: [Int: TitleArt] = [:]
    /// Every slide's art has been asked for and answered, or failed, or
    /// `artPatience` has run out: a slide still without any isn't waiting
    /// for it any more.
    @State private var artsSettled = false
    /// How long the slides wait for their art before showing their backdrop
    /// or poster instead.
    private let artPatience: Duration = .milliseconds(1500)

    /// How the stills move — not at all, unless another take is picked in
    /// Settings' debug section; see `StillsMotion`. Release builds hold
    /// each title's still.
    @AppStorage(StillsMotion.storageKey) private var stillsMotionSetting = StillsMotion.still.rawValue
    private var stillsMotion: StillsMotion {
        #if DEBUG
        StillsMotion(rawValue: stillsMotionSetting) ?? .still
        #else
        .still
        #endif
    }
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    /// User-controlled stop for the rotation. Auto-rotating content has to be
    /// stoppable — a slide that moves on its own every six seconds while
    /// someone is still reading it is the carousel's oldest failure, and it's
    /// worse for anyone who reads slowly or uses a screen reader.
    @State private var autoAdvancePaused = false
    /// On screen — not covered by a pushed page, not scrolled away. Hidden,
    /// the slideshow stands still: slides nobody sees would still animate
    /// and re-render, on the main thread, under whatever *is* on screen.
    @State private var isOnScreen = true

    /// The trailer sheet, while it's up.
    @State private var trailer: HeroTrailerLink?
    /// The title whose trailer is being asked for — its button spins, and
    /// the slideshow holds so the button still belongs to it when it lands.
    @State private var loadingTrailerID: Int?
    /// Each title's trailer once asked for: `.some(nil)` means it has none.
    @State private var trailerURLs: [Int: URL?] = [:]

    /// Something the viewer started is in front of the slideshow, or about
    /// to be: it waits for them, as it does for the pause button.
    private var isHeld: Bool {
        autoAdvancePaused || trailer != nil || loadingTrailerID != nil
    }

    private var isCarousel: Bool { results.count > 1 }
    private var currentIndex: Int { min(max(scrollIndex ?? 0, 0), max(results.count - 1, 0)) }

    /// The hero at `FeaturedHeroMetrics.heightFraction` of its container,
    /// sized the only way each context allows. Exactly one of these runs —
    /// applying both stacks two heights on the same view and leaves a gap
    /// under the artwork.
    @ViewBuilder
    private var sizedHero: some View {
        if let containerHeight {
            heroContent
                .frame(height: containerHeight * FeaturedHeroMetrics.heightFraction, alignment: .top)
        } else {
            heroContent
                .containerRelativeFrame(.vertical, alignment: .top) { height, _ in
                    height * FeaturedHeroMetrics.heightFraction
                }
        }
    }

    var body: some View {
        sizedHero
        .onAppear { isOnScreen = true }
        .onDisappear { isOnScreen = false }
        .onScrollVisibilityChange(threshold: 0.2) { isOnScreen = $0 }
        // Every slide's title logo, asked for together as the hero appears,
        // so each is known before its slide comes round.
        .task(id: results.compactMap(\.id)) {
            let keys = results.compactMap { $0.id.map { TitleLogoStore.Key(id: $0, screenType: screenType) } }
            // Read now, so the first slide's still is fetched at the size
            // the connection allows.
            _ = NetworkConditions.shared
            artsSettled = false
            fillArts(keys)
            await fetchArts(keys)
            artsSettled = true
            await prefetchTrailers()
        }
        .task(id: autoAdvanceKey) {
            // Any change to scrollIndex / scenePhase / isDragging cancels the
            // in-flight sleep and re-enters this task with fresh state. That's
            // how manual swipes reset the dwell timer and how backgrounding
            // halts the carousel without a separate observer.
            guard shouldAutoAdvance else { return }
            do {
                try await Task.sleep(for: slideDwell)
            } catch {
                return // cancelled — task id changed
            }
            guard !Task.isCancelled, shouldAutoAdvance,
                  let current = scrollIndex else { return }
            withAnimation(.easeInOut(duration: AppMotion.slow)) {
                scrollIndex = (current + 1) % results.count
            }
        }
        .modifier(TapToNavigateModifier(
            isEnabled: isTappable,
            onTap: {
                guard results.indices.contains(currentIndex) else { return }
                selectedResult = results[currentIndex]
            }
        ))
        .navigationDestination(item: $selectedResult) { result in
            let model = ContentDetailsModel(screenType: screenType, result: result)
            let vm = ContentDetailsViewModel(model: model)
            ContentDetailsView(detailsViewModel: vm)
        }
        // The same sheet the details screen opens its full trailer in.
        .sheet(item: $trailer) { link in
            WebViewSheet(url: link.url)
        }
        // Title, meta and genre pills are set *on* the artwork inside a slide
        // sized to most of the screen. Past the first accessibility size that
        // copy starts covering the image it is captioning. The details screen
        // one tap away carries the same text with no ceiling.
        .artworkTypeClamp()
    }

    // MARK: - Hero content

    /// The art (pages and scrims) and the copy over it, against a
    /// `GeometryReader`-resolved frame. Relying on `.aspectRatio(.fill)` and
    /// `.frame(maxHeight: .infinity)` instead let the laid-out height drift
    /// past the hero's bounds.
    ///
    /// Only the art stretches, as on the details screen: scaled along with
    /// it, a 30pt title would be hauled up the screen by the pull.
    private var heroContent: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                ZStack {
                    colourWash(height: proxy.size.height)
                        .allowsHitTesting(false)

                    ZStack {
                        stage(size: proxy.size)
                        scrims(height: proxy.size.height)
                            .allowsHitTesting(false)
                    }
                    // The art fades itself out at its foot rather than having
                    // the page colour painted over it, so it blends into
                    // whatever is behind — its own colour first, then the
                    // page — not into a colour that has to match it.
                    .mask { fadeMask(height: proxy.size.height) }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .stretchy()

                if !dissolvesIntoPage {
                    pageEdge
                        .allowsHitTesting(false)
                }

                swipeSurface(size: proxy.size)

                copyBlock(height: proxy.size.height)
            }
        }
    }

    /// Asks for every slide's art together and shows each slide's as it
    /// lands. Shown only once the slowest had answered, one stalled request
    /// held every slide on black until it gave up — a minute, on a bad
    /// connection. Past `artPatience`, the slides still waiting settle for
    /// what they have; art that lands after that dissolves in over it.
    private func fetchArts(_ keys: [TitleLogoStore.Key]) async {
        guard !keys.isEmpty else { return }
        let store = TitleLogoStore.shared
        let patience = artPatience
        await withTaskGroup(of: TitleLogoStore.Key?.self) { group in
            group.addTask {
                try? await Task.sleep(for: patience)
                return nil
            }
            for key in keys {
                group.addTask {
                    _ = await store.art(for: key)
                    return key
                }
            }
            var waiting = keys.count
            for await key in group {
                guard let key else {
                    artsSettled = true
                    continue
                }
                fillArts([key])
                waiting -= 1
                // All answered: nothing left for the patience timer to cut short.
                if waiting == 0 { group.cancelAll() }
            }
        }
    }

    /// Copies whatever art the store has for these slides into view state.
    private func fillArts(_ keys: [TitleLogoStore.Key]) {
        for key in keys {
            if let art = TitleLogoStore.shared.cachedArt(key), arts[key.id] != art {
                arts[key.id] = art
            }
        }
    }

    // MARK: - Slides

    /// The slide on screen. A new title blends in over the last — the
    /// outgoing one fading while the next comes up — rather than sliding
    /// across. The art drifts down a third as far as the page scrolls up,
    /// as the details hero's does.
    private func stage(size: CGSize) -> some View {
        let scrollParallax: CGFloat = reduceMotion ? 0 : 0.35

        return ZStack {
            ForEach([currentIndex], id: \.self) { index in
                if results.indices.contains(index) {
                    slideArt(for: index, size: size)
                        .frame(width: size.width, height: size.height)
                        .transition(.opacity)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .animation(.easeInOut(duration: reduceMotion ? AppMotion.standard : 0.9), value: currentIndex)
        .visualEffect { content, geometry in
            let scrolled = max(0, -geometry.frame(in: .scrollView(axis: .vertical)).minY)
            return content.offset(y: scrolled * scrollParallax)
        }
        .accessibilityHidden(true)
    }

    /// Takes the swipes. A native paging scroll view, so a horizontal swipe
    /// changes title and a vertical one still scrolls the page — but with
    /// nothing in it to see: what it moves is `scrollIndex`, and the stage
    /// behind blends to the new title. A gesture of our own here used to
    /// swallow the page's vertical scrolling.
    private func swipeSurface(size: CGSize) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(results.indices, id: \.self) { index in
                    Color.clear
                        .frame(width: size.width, height: size.height)
                        .contentShape(Rectangle())
                        .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrollIndex)
        .scrollDisabled(!isCarousel)
        // A scroll view whose top edge sits under the status bar draws its
        // own soft edge effect there on iOS 26 — a haze over the art below.
        .modifier(TopScrollEdgeEffectHidden(hidden: true))
        // Only needed to hold the auto-advance while a finger is on it.
        .onScrollPhaseChange { _, newPhase in
            isDragging = (newPhase == .interacting || newPhase == .tracking)
        }
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }

    /// Where the dissolve at the foot starts, as a fraction of the hero's
    /// height.
    private func fadeStart(height: CGFloat) -> CGFloat {
        max(0.4, 1 - fadeHeight / max(height, 1))
    }

    /// On a dark page the picture's shadow dissolves into it, and there's
    /// no telling where the hero ends. On a light one any dissolve from that
    /// shadow to white passes through grey — the "muddy" stretch — so the
    /// picture stays whole to its foot, and the page meets it on an edge.
    private var dissolvesIntoPage: Bool { colorScheme == .dark }

    /// The top of the light page, laid over the picture's foot with rounded
    /// corners, as if the page were a sheet drawn up over the hero. The
    /// picture shows in the corners, so the hero reads as running on under
    /// the page rather than being cut off.
    private var pageEdge: some View {
        UnevenRoundedRectangle(topLeadingRadius: AppRadius.surface,
                               topTrailingRadius: AppRadius.surface,
                               style: .continuous)
            .fill(pageColor)
            .frame(height: AppRadius.surface)
            .frame(maxWidth: .infinity)
    }

    /// Where the darkening behind the copy begins and where it's at full
    /// strength, as fractions of the hero's height — measured up from the
    /// foot, because the copy is: it starts well above the badge and is
    /// whole by the logo.
    private func shadeRange(height: CGFloat) -> (start: CGFloat, full: CGFloat) {
        let h = max(height, 1)
        let start = max(0.2, 1 - 440 / h)
        return (start, max(start + 0.1, 1 - 250 / h))
    }

    /// Two layers, after the details hero's: a shade under the status bar
    /// and the tab's title, and a darkening behind the copy. The dissolve
    /// into the page, where there is one, is the mask's (`fadeMask`).
    ///
    /// The darkening comes in along a smoothstep, sampled so no stop shows
    /// as a band, and is dark enough by the logo for white copy on the
    /// brightest still — the still stays sharp under it, as a frosting
    /// here made the hero read as out of focus. Where the hero dissolves it
    /// eases off through the dissolve; where it meets the page on an edge it
    /// holds to the edge.
    private func scrims(height: CGFloat) -> some View {
        let fadeStart = fadeStart(height: height)
        let tail = 1 - fadeStart
        let shade = shadeRange(height: height)
        let easeIn: [Gradient.Stop] = (0...10).map { step in
            let t = Double(step) / 10
            return .init(color: .black.opacity(0.62 * t * t * (3 - 2 * t)),
                         location: shade.start + (shade.full - shade.start) * t)
        }
        let foot: [Gradient.Stop] = dissolvesIntoPage
            ? [.init(color: .black.opacity(0.66), location: fadeStart),
               .init(color: .black.opacity(0.3), location: fadeStart + tail * 0.5),
               .init(color: .clear, location: fadeStart + tail * 0.85)]
            : [.init(color: .black.opacity(0.72), location: 1)]

        return ZStack {
            LinearGradient(colors: [.black.opacity(0.55), .black.opacity(0.15), .clear],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 170)
                .frame(maxHeight: .infinity, alignment: .top)

            LinearGradient(stops: easeIn + foot, startPoint: .top, endPoint: .bottom)
        }
    }

    /// The slide's own colour, showing through where the picture dissolves:
    /// the art fades into a wash of itself before it reaches the page, and
    /// the wash turns to the next slide's colour as the slides change. The
    /// hero's foot belongs to whatever it's showing.
    private func colourWash(height: CGFloat) -> some View {
        let start = fadeStart(height: height)
        let tail = 1 - start
        let tint = slideTints[currentIndex] ?? .clear
        // Strongest low in the dissolve, where the picture has mostly gone:
        // higher up the art hides it, and lower down the page takes over.
        // There, the foot reads as the picture's glow rather than grey.
        return LinearGradient(stops: [.init(color: tint.opacity(0), location: max(0, start - 0.08)),
                                      .init(color: tint.opacity(0.4), location: start + tail * 0.4),
                                      .init(color: tint.opacity(0.75), location: start + tail * 0.72),
                                      .init(color: tint.opacity(0), location: 1)],
                              startPoint: .top, endPoint: .bottom)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.9), value: tint)
    }

    /// Takes a slide's colour from its decoded poster, once per slide. The
    /// average is a blocking CoreImage render, so it runs off the main actor.
    private func cacheTintIfNeeded(for index: Int, image: UIImage) {
        guard slideTints[index] == nil else { return }
        Task.detached(priority: .utility) {
            guard let tint = image.heroTint else { return }
            await MainActor.run { slideTints[index] = Color(tint) }
        }
    }

    /// Opaque down to the dissolve, then fading to clear along a smoothstep
    /// cubed, sampled at sixteen points: flat at both ends, so neither the
    /// top nor the foot of the fade shows as a line, and faint through its
    /// upper half, so the copy can sit low without the page washing it out.
    /// A gradient runs in straight lines between stops; with only a few, the
    /// eye catches the corners as bands.
    ///
    /// None at all on a light page: see `dissolvesIntoPage`.
    private func fadeMask(height: CGFloat) -> some View {
        guard dissolvesIntoPage else {
            return LinearGradient(colors: [.black], startPoint: .top, endPoint: .bottom)
        }
        let start = fadeStart(height: height)
        let eased: [Gradient.Stop] = (0...16).map { step in
            let t = Double(step) / 16
            let smooth = t * t * (3 - 2 * t)
            return .init(color: .black.opacity(1 - smooth * smooth * smooth),
                         location: start + (1 - start) * t)
        }
        return LinearGradient(stops: [.init(color: .black, location: 0)] + eased,
                              startPoint: .top, endPoint: .bottom)
    }

    // MARK: - Copy

    /// A slide's picture: the title's best still, framed on its subject (see
    /// `HeroStillProcessor`), moving only if the debug section says so.
    private func slideArt(for index: Int, size: CGSize) -> some View {
        StillsArt(urls: pictures(for: results[index]),
                         isActive: index == currentIndex && isOnScreen
                             && scenePhase == .active && !isHeld,
                         motion: stillsMotion) { image in
            cacheTintIfNeeded(for: index, image: image)
        }
    }

    /// What a slide can show, best first: the title's own textless stills.
    /// While they're being asked for, nothing — a moment of the hero's black
    /// rather than a stand-in swapped out a beat later; the poster used to
    /// stand in, title and all, under the logo. Only for a title with no
    /// stills, once that's known, its backdrop, then its textless poster,
    /// then its poster.
    private func pictures(for result: Result) -> [URL] {
        let art = result.id.flatMap { arts[$0] }
        if let art, !art.stillPaths.isEmpty {
            return art.stillPaths.compactMap(HeroStill.url(path:))
        }
        guard art != nil || artsSettled else { return [] }
        if let backdrop = result.backdrop_path, let url = HeroStill.url(path: backdrop) {
            return [url]
        }
        return [art?.cleanPoster ?? result.getResultPosterURL()]
    }

    /// The slide's copy, then the actions and the dots — all centred, the
    /// copy rising in with each slide and the rest staying put, so the
    /// buttons are where the thumb left them when the title moves on. Fades
    /// over the first half of the hero's height as the page scrolls, so it
    /// doesn't pass under the bars at full strength.
    private func copyBlock(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            slideCopy
            if results.indices.contains(currentIndex) {
                actionRow(for: results[currentIndex])
                    .padding(.top, 20)
            }
            if isCarousel {
                pageIndicator
                    .padding(.top, 18)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, copyLift)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .visualEffect { content, geometry in
            let scrolled = max(0, -geometry.frame(in: .scrollView(axis: .vertical)).minY)
            return content.opacity(1 - min(1, scrolled / max(1, height * 0.5)))
        }
    }

    /// Trailer, the one thing worth doing before deciding, and Watch Later,
    /// the one thing worth doing after. Everything else is a tap on the
    /// picture away, on the details screen.
    private func actionRow(for result: Result) -> some View {
        HStack(spacing: 12) {
            HeroTrailerButton(isLoading: loadingTrailerID != nil && loadingTrailerID == result.id,
                              hasTrailer: !isKnownToHaveNoTrailer(result)) {
                playTrailer(for: result)
            }
            HeroWatchlistButton(result: result, screenType: screenType, isOnScreen: isOnScreen)
                // A fresh button per title, so one title's saved state
                // never animates into the next one's.
                .id(result.id)
        }
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Trailer

    /// Asks for every slide's trailer as the hero appears, so a slide with
    /// none says so on its button before it's tapped rather than after.
    private func prefetchTrailers() async {
        let screenType = screenType
        let ids = results.compactMap(\.id).filter { trailerURLs[$0] == nil }
        await withTaskGroup(of: (id: Int, url: URL?, answered: Bool).self) { group in
            for id in ids {
                group.addTask {
                    let videos = try? await ServiceInvocation().fetchVideos(screenType: screenType, id: String(id))
                    return (id, videos?.getVideoURL(), videos != nil)
                }
            }
            // Only an answer is remembered; a failed request asks again on tap.
            for await answer in group where answer.answered {
                trailerURLs[answer.id] = .some(answer.url)
            }
        }
    }

    /// TMDB has answered for this title, and it has no trailer.
    private func isKnownToHaveNoTrailer(_ result: Result) -> Bool {
        guard let id = result.id, let known = trailerURLs[id] else { return false }
        return known == nil
    }

    /// Opens the title's trailer, asking TMDB for it the first time.
    private func playTrailer(for result: Result) {
        guard let id = result.id, loadingTrailerID == nil else { return }
        if let known = trailerURLs[id] {
            openTrailer(known, for: result)
            return
        }
        loadingTrailerID = id
        let screenType = screenType
        Task {
            let videos = try? await ServiceInvocation().fetchVideos(screenType: screenType, id: String(id))
            // Only an answer is remembered; a failed request asks again.
            if let videos { trailerURLs[id] = .some(videos.getVideoURL()) }
            loadingTrailerID = nil
            openTrailer(videos?.getVideoURL(), for: result)
        }
    }

    /// The trailer where there is one. Where there isn't — or it couldn't
    /// be asked for — the details screen, which is where the tap was going
    /// anyway: the title, its services and everything else about it.
    private func openTrailer(_ url: URL?, for result: Result) {
        if let url {
            trailer = HeroTrailerLink(url: url)
        } else {
            selectedResult = result
        }
    }

    private var slideCopy: some View {
        ZStack(alignment: .bottom) {
            if results.indices.contains(currentIndex) {
                overlayContent(results[currentIndex])
                    .id(currentIndex)
                    .transition(copyTransition)
            }
        }
        .animation(.default, value: currentIndex)
    }

    private var pageIndicator: some View {
        HeroPageIndicator(count: results.count,
                          current: currentIndex,
                          dwell: dwellSeconds,
                          isRunning: shouldAutoAdvance,
                          isPaused: $autoAdvancePaused)
    }

    /// The outgoing copy leaves fast and the incoming copy rises in just
    /// after it, so the two titles are never on screen at once — crossfaded
    /// together, they stacked into an unreadable double exposure mid-swipe.
    private var copyTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .offset(y: reduceMotion ? 0 : 18))
                .animation(reduceMotion ? .easeIn(duration: AppMotion.standard).delay(0.12)
                                        : .spring(response: 0.55, dampingFraction: 0.85).delay(0.12)),
            removal: .opacity.animation(.easeOut(duration: 0.12)))
    }

    // MARK: - Auto-advance plumbing

    /// Reduce Motion stops the rotation outright rather than speeding it up:
    /// the slides still exist and are still swipeable, they just don't move
    /// on their own. With nothing moving there is nothing to pause, which is
    /// why the control hides itself in that state.
    private var shouldAutoAdvance: Bool {
        scenePhase == .active && isOnScreen && !isDragging && isCarousel
            && !reduceMotion && !isHeld
    }

    private var autoAdvanceKey: AutoAdvanceKey {
        AutoAdvanceKey(tab: scrollIndex ?? 0,
                       isActive: scenePhase == .active && isOnScreen,
                       isDragging: isDragging,
                       slideCount: results.count,
                       isPaused: isHeld || reduceMotion)
    }

    private struct AutoAdvanceKey: Equatable {
        let tab: Int
        let isActive: Bool
        let isDragging: Bool
        let slideCount: Int
        let isPaused: Bool
    }
}

// MARK: - HeroSlideCopy

/// One hero slide's copy, the same on every hero, centred: a badge, the
/// title, and one line of facts — rating, year and up to two genres. Set in
/// white with no background or shadow of its own — the hero's scrims
/// carry its legibility, and a shadow redrawn under every slide's
/// entrance stuttered it.
///
/// The kicker is a slot: the feed's ranks the title in the row it comes
/// from, a streaming service's names the service and switches between them.
struct HeroSlideCopy<Kicker: View>: View {
    let result: Result
    /// Movies or series — which catalogue the title's logo is looked up in.
    let screenType: ScreenTypes
    let kicker: Kicker

    init(result: Result, screenType: ScreenTypes, @ViewBuilder kicker: () -> Kicker) {
        self.result = result
        self.screenType = screenType
        self.kicker = kicker()
    }

    var body: some View {
        VStack(spacing: 14) {
            kicker

            HeroTitleArt(result: result, screenType: screenType)

            facts
        }
        .frame(maxWidth: .infinity)
    }

    /// Rating, year, genres, on one line with a dot between each — a
    /// caption under the logo rather than a row of chips competing with it.
    private var facts: some View {
        let rating = result.vote_average.flatMap { $0 > 0 ? $0 : nil }
        let year = result.getReleaseDate(addSeparator: false)
        let genres = (result.genre_ids ?? []).prefix(2).compactMap(GenreNames.shared.name)
        let words = ([year] + genres).filter { !$0.isEmpty }

        return HStack(spacing: 8) {
            if let rating {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .appFont(11, relativeTo: .caption2)
                        .foregroundStyle(RatingStyle.tint(for: rating))
                    Text(rating.ratingText)
                }
            }
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                if rating != nil || index > 0 {
                    Circle()
                        .fill(.white.opacity(0.5))
                        .frame(width: 3, height: 3)
                }
                Text(verbatim: word)
            }
        }
        .appFont(14, weight: .medium, relativeTo: .subheadline)
        .foregroundStyle(.white.opacity(0.88))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - HeroTitleArt

/// A slide's title: the title's own logo where TMDB has one, its name in
/// our type where it doesn't.
///
/// Holds its place, invisibly, while the answer is on its way — up to the
/// better part of a second, then the name — so a slide never shows its name
/// and then swaps it for the logo. A logo too dark for the hero's scrim is
/// drawn in white.
struct HeroTitleArt: View {
    let result: Result
    let screenType: ScreenTypes

    private enum Phase: Equatable {
        case pending
        case logo(TitleLogo)
        case name
    }

    @State private var phase: Phase
    @State private var logoShown = false
    @State private var logoIsDark = false

    /// The widest and tallest a logo is drawn. Large — it's the slide's
    /// headline, and the art behind it is the only thing bigger.
    private let maxLogoWidth: CGFloat = 300
    private let maxLogoHeight: CGFloat = 108

    init(result: Result, screenType: ScreenTypes) {
        self.result = result
        self.screenType = screenType
        let key = TitleLogoStore.Key(id: result.id ?? 0, screenType: screenType)
        switch TitleLogoStore.shared.cached(key) {
        case .some(.some(let logo)): _phase = State(initialValue: .logo(logo))
        case .some(.none):           _phase = State(initialValue: .name)
        case .none:                  _phase = State(initialValue: .pending)
        }
    }

    private var key: TitleLogoStore.Key {
        TitleLogoStore.Key(id: result.id ?? 0, screenType: screenType)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            switch phase {
            case .pending:
                name.hidden()
            case .name:
                name
            case .logo(let logo):
                logoArt(logo)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(result.getResultTitle()))
        .accessibilityAddTraits(.isHeader)
        .task(id: key) {
            guard phase == .pending else { return }
            // Long enough for a cold request; past it, the name rather than
            // a gap where the title should be.
            let fallback = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(800))
                if !Task.isCancelled, phase == .pending { phase = .name }
            }
            let logo = await TitleLogoStore.shared.logo(for: key)
            fallback.cancel()
            guard phase == .pending else { return }
            phase = logo.map(Phase.logo) ?? .name
        }
    }

    private var name: some View {
        Text(result.getResultTitle())
            .appFont(34, weight: .heavy, relativeTo: .largeTitle)
            .tracking(-0.4)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.75)
    }

    private func logoArt(_ logo: TitleLogo) -> some View {
        let ratio = max(logo.aspectRatio, 0.5)
        let width = min(maxLogoWidth, maxLogoHeight * ratio)
        return KFImage.url(logo.url)
            .onSuccess { result in
                let image = result.image
                Task.detached(priority: .userInitiated) {
                    let isDark = (image.inkLuminance ?? 1) < 0.32
                    await MainActor.run {
                        logoIsDark = isDark
                        logoShown = true
                    }
                }
            }
            // A logo that won't load leaves the name, not a blank.
            .onFailure { _ in phase = .name }
            .loadImmediately()
            .cacheOriginalImage()
            .backgroundDecode()
            .renderingMode(logoIsDark ? .template : .original)
            .resizable()
            .foregroundStyle(.white)
            .aspectRatio(ratio, contentMode: .fit)
            .frame(width: width, height: width / ratio, alignment: .bottom)
            .opacity(logoShown ? 1 : 0)
            .animation(.easeOut(duration: AppMotion.standard), value: logoShown)
    }
}

/// The feed hero's badge: where the title ranks in the row it leads, in
/// the same gold, silver and bronze `#N` chip as that row's cards just
/// below, then the row's name.
struct HeroRankKicker: View {
    /// 1-based.
    let rank: Int
    let label: String
    let isSeries: Bool

    var body: some View {
        HStack(spacing: 7) {
            HStack(spacing: 1) {
                Text(verbatim: "#")
                    .appFont(10, weight: .bold, relativeTo: .caption2, design: .rounded)
                    .opacity(0.8)
                Text(verbatim: "\(rank)")
                    .appFont(12, weight: .heavy, relativeTo: .caption, design: .rounded)
            }
            // Dark on the metals: white on silver all but disappears at
            // this size.
            .foregroundStyle(rank <= 3 ? Color.black.opacity(0.82) : .white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(RankTint.color(for: rank, isSeries: isSeries), in: Capsule())

            Text(verbatim: label.uppercased(with: .current))
                .heroKickerStyle()
                .lineLimit(1)
        }
        .heroBadge(leading: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Number \(rank) in \(label)",
                                 comment: "Accessibility: the hero's badge, e.g. Number 2 in Hot Right Now"))
    }
}

extension View {
    /// The kicker's type, for a kicker built from more than text.
    func heroKickerStyle() -> some View {
        self
            .appFont(11, weight: .semibold, relativeTo: .caption)
            .tracking(1.2)
            .foregroundStyle(.white.opacity(0.92))
    }

    /// A hero's badge: the kicker in a capsule of glass over the picture.
    /// `leading` is tighter where the badge opens on a chip or a logo, so
    /// the round shape inside sits evenly in the round end.
    func heroBadge(leading: CGFloat = 12) -> some View {
        self
            .padding(.leading, leading)
            .padding(.trailing, 12)
            .padding(.vertical, 5)
            .modifier(HeroBadgeBackground())
    }
}

/// Liquid glass on iOS 26, a dark thin material with a hairline before.
/// Dark either way: the badge sits on the picture, not on the page.
private struct HeroBadgeBackground: ViewModifier {
    func body(content: Content) -> some View {
        Group {
            if #available(iOS 26.0, *) {
                content.glassEffect(.regular, in: Capsule())
            } else {
                content
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
            }
        }
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Hero actions

/// A trailer to show in a sheet.
private struct HeroTrailerLink: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// The hero's lead action: a solid white pill, the one opaque thing on the
/// picture, so it's the first thing the eye and the thumb find. Spins in
/// place while the trailer is being found. For a title with no trailer it
/// says where it goes instead — the details screen — rather than promising
/// a trailer and opening that.
private struct HeroTrailerButton: View {
    let isLoading: Bool
    var hasTrailer = true
    let action: () -> Void

    private var label: String {
        hasTrailer ? String(localized: "Trailer", comment: "Button: play the trailer")
                   : String(localized: "More info")
    }

    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 50

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ZStack {
                    Image(systemName: hasTrailer ? "play.fill" : "info.circle.fill")
                        .appFont(15, weight: .bold, relativeTo: .body)
                        .foregroundStyle(Color.accentColor)
                        .contentTransition(.symbolEffect(.replace))
                        .opacity(isLoading ? 0 : 1)
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.black)
                    }
                }
                Text(label)
                    .appFont(17, weight: .semibold, relativeTo: .body)
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .contentTransition(.interpolate)
            }
            .padding(.horizontal, 26)
            .frame(minWidth: 172)
            .frame(height: height)
            .background(.white, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(HeroPressStyle())
        .animation(.snappy, value: hasTrailer)
        .accessibilityLabel(Text(label))
    }
}

/// Watch Later, as a glass circle beside Trailer: the bookmark the details
/// screen saves with, filling with the accent once the title is saved.
private struct HeroWatchlistButton: View {
    let result: Result
    let screenType: ScreenTypes
    /// The hero is on screen. Coming back to it — from a details screen, say
    /// — the title may have been saved or removed there; it's read again.
    let isOnScreen: Bool

    @State private var isSaved = false
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 50

    var body: some View {
        Button(action: toggle) {
            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                .appFont(18, weight: .semibold, relativeTo: .body)
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace.downUp))
                .frame(width: size, height: size)
                .modifier(HeroCircleBackground(isOn: isSaved))
                .contentShape(Circle())
        }
        .buttonStyle(HeroPressStyle())
        .onAppear(perform: readSaved)
        .onChange(of: isOnScreen) { _, onScreen in
            if onScreen { readSaved() }
        }
        .accessibilityLabel(isSaved
                            ? Text("Remove from Watchlist")
                            : Text(String(localized: "Watch Later", comment: "Button: add the title to the watchlist")))
    }

    private func readSaved() {
        isSaved = WatchlistManager.existsInWatchList(result: saveable)
    }

    /// The title as the watchlist keeps it. Rows from a service's catalogue
    /// come without a `media_type`, which the watchlist needs to tell a
    /// movie from a series with the same id.
    private var saveable: Result {
        var item = result
        if item.media_type == nil {
            item.media_type = screenType == .tv ? "tv" : "movie"
        }
        return item
    }

    private func toggle() {
        let item = saveable
        if isSaved {
            WatchlistManager.removeFromWatchList(result: item)
            isSaved = false
        } else {
            let added = WatchlistManager.addToWatchList(result: item)
            isSaved = true
            if added {
                // As saving from anywhere else: the first save is the moment
                // to offer alerts, and a save counts towards a review ask.
                Task { await NotificationPermission.shared.offerAfterSave() }
                ReviewRequestManager.recordWatchlistAdd()
                ReviewRequestManager.requestReview(for: .savedTitle)
            }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

/// Glass on iOS 26, tinted with the accent while on; the dark thin
/// material before, filled with the accent while on.
private struct HeroCircleBackground: ViewModifier {
    let isOn: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(isOn ? .regular.tint(.accentColor).interactive() : .regular.interactive(),
                                in: Circle())
        } else {
            content
                .background {
                    ZStack {
                        Circle().fill(.ultraThinMaterial)
                        if isOn { Circle().fill(Color.accentColor) }
                    }
                }
                .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
        }
    }
}

/// A squeeze on touch-down, let go with a little spring.
private struct HeroPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            // On under Reduce Motion too, as `PressableCardStyle`: a press
            // confined to the control under the finger is response, not
            // motion.
            .animation(AppMotion.springSnappy, value: configuration.isPressed)
    }
}

// MARK: - HeroPageIndicator

/// A hero's page indicator: dots, the current one a capsule that fills over
/// its slide's dwell, and a button that stops and starts the rotation.
/// Shared by the feed's hero and a streaming service's catalogue, so the
/// two count down the same way. Bare, on the hero's shade: in a glass
/// pill of their own they were one more surface under the buttons.
struct HeroPageIndicator: View {
    let count: Int
    let current: Int
    /// Seconds a slide shows before the next — what the current dot counts.
    let dwell: Double
    /// The countdown is live: on screen, not paused, no finger on it.
    let isRunning: Bool
    @Binding var isPaused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The dots and the countdown capsule. Small on purpose: the pill says
    /// where you are and that it's moving, and the slide is what's worth
    /// looking at.
    private static let dot: CGFloat = 6
    fileprivate static let capsuleWidth: CGFloat = 22

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                let isActive = index == current
                Group {
                    if isActive {
                        ProgressCapsule(duration: dwell, isRunning: isRunning)
                    } else {
                        Capsule()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: Self.dot, height: Self.dot)
                    }
                }
                // Recreated when a dot turns active or inactive, so the
                // capsule's `onAppear` fires on a fresh view.
                .id("\(index)-\(isActive)")
                .animation(.easeInOut(duration: AppMotion.standard), value: current)
            }
            // Dots are decoration; the position is announced once, as a
            // sentence, on the row itself.
            .accessibilityHidden(true)

            // Reduce Motion stops the rotation outright, so there's nothing
            // to pause.
            if count > 1, !reduceMotion {
                pauseControl
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Slide \(current + 1) of \(count)",
                                 comment: "Accessibility: featured carousel position"))
    }

    /// Stop/start for the rotation, tucked into the pill so it costs no new
    /// chrome. The glyph is small; the tap area is not.
    private var pauseControl: some View {
        Button {
            isPaused.toggle()
        } label: {
            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                .appFont(8, weight: .bold, relativeTo: .caption2)
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Extends past the pill rather than inflating it — the visible pill
        // keeps its proportions while the target reaches 44pt.
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .padding(.leading, -12)
        .padding(.trailing, -10)
        .padding(.vertical, -12)
        .accessibilityLabel(isPaused ? "Play slideshow" : "Pause slideshow")
    }

    /// A 22 × 6 pt capsule that fills left to right over `duration` seconds.
    ///
    /// Two things the animation has to survive:
    /// 1. On reappear, `progress` may still be at 1 from a previous cycle; a
    ///    plain `withAnimation { progress = 1 }` sees no change and skips it.
    /// 2. Backgrounding snaps in-flight animations to their end. When the app
    ///    comes back the rotation restarts its wait, but this view isn't
    ///    recreated, so it would sit full for the next dwell.
    ///
    /// So: reset to 0 with animations disabled, then start the linear fill on
    /// the next runloop tick, once the reset has committed — and again when
    /// the scene comes back to the foreground.
    private struct ProgressCapsule: View {
        let duration: Double
        /// False when the rotation is paused or Reduce Motion is on: the
        /// capsule then shows full, as held, instead of counting down to an
        /// advance that isn't coming.
        let isRunning: Bool
        @State private var progress: CGFloat = 0
        @Environment(\.scenePhase) private var scenePhase

        var body: some View {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                Capsule()
                    .fill(Color.white.opacity(0.95))
                    .scaleEffect(x: progress, anchor: .leading)
            }
            .frame(width: HeroPageIndicator.capsuleWidth, height: HeroPageIndicator.dot)
            .clipShape(Capsule())
            .onAppear { restartAnimation() }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active { restartAnimation() }
            }
            .onChange(of: isRunning) { _, _ in restartAnimation() }
        }

        private func restartAnimation() {
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) { progress = 0 }
            guard isRunning else {
                var hold = Transaction()
                hold.disablesAnimations = true
                withTransaction(hold) { progress = 1 }
                return
            }
            DispatchQueue.main.async {
                withAnimation(.linear(duration: duration)) { progress = 1 }
            }
        }
    }
}

/// Attaches a tap gesture only when enabled. Avoids installing an idle gesture
/// recognizer on the hero when it is not meant to navigate anywhere.
private struct TapToNavigateModifier: ViewModifier {
    let isEnabled: Bool
    let onTap: () -> Void

    func body(content: Content) -> some View {
        if isEnabled {
            content.onTapGesture { onTap() }
        } else {
            content
        }
    }
}

// MARK: - Hero tint extraction
//
// Colour sampling for the details screen, which takes its page colour from
// the hero artwork. Lived here when the feed hero tinted a blurred backdrop
// with it too; that backdrop is gone, the helper stays put.

extension UIImage {

    /// Single-pixel area-average over the whole image. Cheap, but runs
    /// on a blocking CIContext render — call off the main actor.
    fileprivate var averageColor: UIColor? {
        guard let inputImage = CIImage(image: self) else { return nil }

        let extent = inputImage.extent
        let extentVector = CIVector(x: extent.origin.x,
                                    y: extent.origin.y,
                                    z: extent.size.width,
                                    w: extent.size.height)

        guard let filter = CIFilter(name: "CIAreaAverage",
                                    parameters: [kCIInputImageKey: inputImage,
                                                 kCIInputExtentKey: extentVector]),
              let outputImage = filter.outputImage
        else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        // Working in the default RGB space is fine — we only use this
        // for UI tinting, not colour-matching.
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(outputImage,
                       toBitmap: &bitmap,
                       rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8,
                       colorSpace: nil)

        return UIColor(red: CGFloat(bitmap[0]) / 255.0,
                       green: CGFloat(bitmap[1]) / 255.0,
                       blue: CGFloat(bitmap[2]) / 255.0,
                       alpha: CGFloat(bitmap[3]) / 255.0)
    }

    /// Slightly saturated variant of `averageColor`. Raw averages tend
    /// toward muddy grays, which read as "tired" in a hero wash; bumping
    /// saturation pulls the tint back toward the poster's personality
    /// without committing to a full dominant-hue extractor.
    var heroTint: UIColor? {
        guard let avg = averageColor else { return nil }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard avg.getHue(&hue, saturation: &saturation,
                         brightness: &brightness, alpha: &alpha) else { return avg }

        // Clamp saturation upward and brightness to a mid-range so the
        // wash never goes fully black or fully white regardless of source.
        let boostedSaturation = min(max(saturation * 1.4, 0.35), 0.8)
        let clampedBrightness = min(max(brightness, 0.25), 0.55)

        return UIColor(hue: hue,
                       saturation: boostedSaturation,
                       brightness: clampedBrightness,
                       alpha: alpha)
    }
}
