//
//  DetailsHeroView.swift
//  Watchnow
//
//  The top of the details screen: the title, its meta line and genres, set
//  over the artwork.
//
//  Sized by its content, not by the screen. The hero used to be a fixed
//  share of the screen height (first 75%, then 50%), which was always
//  wrong somewhere: too tall to get the actions and Coach's read above the
//  fold on a Pro Max, too short for a two-line title under the nav buttons
//  on an SE. Now it is exactly the room under the floating nav buttons plus
//  the copy, with a floor so a short movie title still gets a strip of
//  picture.
//
//  The backdrop — the title's wide image — because a short, wide band is
//  its native shape; a portrait poster cropped to a third of itself shows a
//  forehead or a billing block. The poster appears further down, in the
//  Coach card, and is the fallback for a title without a backdrop.
//
//  Nothing has fetched the backdrop before this screen (every list shows
//  posters), so it can't be instant. The poster those lists already cached
//  — same URL, so a memory-cache hit — fills the band first, blurred into a
//  wash of the title's own colours, and the backdrop comes into focus over
//  it when it lands. It loads through `RemoteImage`, which, unlike
//  `KFImage`, can't lose a finished download to a re-render; the hero is
//  also exempt from the screen's loading redaction, since its title is
//  known from the list row.
//
//  Motion: the copy rises in line by line when the screen opens; on scroll
//  the picture drifts at a third of the page's speed and the copy fades as
//  it leaves, so the hero recedes rather than being pushed off.
//
//  The trailer (`HeroTrailerView`), when the reader taps Trailer: the
//  backdrop gives way to the playing trailer, the title steps aside, and
//  the hero grows to hold the
//  whole 16:9 player between the nav buttons and the fade into the page.
//  It's the reader's: YouTube's own controls — pause, seek, sound,
//  captions, full screen. Meanwhile the Trailer action reads Close, which
//  brings the backdrop and the title back; so does the trailer ending or
//  the page going. Scrolling it away or a sheet over the page pauses it,
//  and it carries on when it's back in view — unless the reader had paused
//  it. Where YouTube won't play it here, the Trailer action opens the full
//  trailer instead.
//
import SwiftUI

struct DetailsHeroView: View {

    /// "SERIES" / "MOVIE" — what kind of thing this page is about.
    let kind: String?
    let title: String
    let rating: Double?
    let year: String?
    let runtimeOrSeasons: String?
    let genres: [Genres]
    let backdropPath: String?
    let posterPath: String?
    /// The status bar and floating nav buttons, which sit over the top of
    /// the artwork. The copy starts below them.
    let topInset: CGFloat
    /// Series: how long an episode usually runs, in minutes.
    var episodeMinutes: Int? = nil
    /// "TV-MA", "PG-13", "16" — set in a rating box at the end of the meta.
    var certification: String? = nil
    /// Names of the user's own services this streams on — the first pill.
    var ownedServices: [String] = []
    /// What the bottom edge dissolves into: the page colour, which the
    /// artwork tints.
    var pageColor: Color = Color(.background)
    /// Hands over the hero image once it's on screen, so the page can take
    /// its colour from it.
    var onArtwork: (UIImage) -> Void = { _ in }
    /// YouTube id of the trailer to play in the hero — see
    /// `HeroTrailerView`. Nil for none.
    var trailerKey: String? = nil
    /// A sheet is up over the page: the trailer pauses, and doesn't start —
    /// it mustn't play, or be heard, behind one.
    var isCovered: Bool = false
    /// The trailer is on screen. The page shows it on the Trailer action
    /// (as Close) and sets it back to false to close the trailer.
    var trailerPlaying: Binding<Bool> = .constant(false)
    /// Opens the full trailer — for when it can't play here.
    var onFullTrailer: () -> Void = {}

    /// Breathing room between the genre pills and the action row, which
    /// overlaps the bottom of the hero by `actionOverlap`.
    static let actionOverlap: CGFloat = 32
    private let bottomPadding: CGFloat = actionOverlap + 14
    private let fadeHeight: CGFloat = 64

    @State private var copyShown = false
    @State private var heroWidth: CGFloat = 0

    /// Where the trailer is.
    private enum TrailerPhase: Equatable {
        /// Backdrop and copy; no video.
        case idle
        /// The player is loading, under the backdrop.
        case loading
        /// Playing, the copy out of the way, the player the reader's.
        case watching
    }

    @State private var trailerPhase: TrailerPhase = .idle
    /// The hero is the trailer's: open to the player's size, the copy and
    /// its scrim out of the way, the backdrop its ambience. From the tap
    /// on, so everything that moves, moves once — right away, in answer to
    /// the tap — and the video then fades in where it will stay.
    private var trailerUp: Bool { trailerPhase != .idle }
    private var copyHidden: Bool { trailerUp }
    /// The video itself is on screen.
    private var videoShown: Bool { trailerPhase == .watching }
    /// What the Trailer action shows as Close: the trailer on screen or on
    /// its way.
    private var trailerActive: Bool { trailerPhase != .idle }
    /// Bumped per play, so a replay gets a fresh player and the timers of
    /// the last one can tell they're stale.
    @State private var trailerSession = 0
    /// YouTube refused this one — don't offer it again.
    @State private var trailerUnavailable = false
    /// The current player has reported playing.
    @State private var trailerDidPlay = false
    /// Pauses the player from here.
    @State private var trailerRemote = TrailerRemote()
    /// The page paused the trailer — scrolled away, a sheet came up — and
    /// owes the reader a resume when that's over.
    @State private var pausedByPage = false
    @State private var heroVisible = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                if let kind {
                    Text(kind.uppercased(with: .current))
                        .appFont(12, weight: .semibold, relativeTo: .caption)
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.85))
                        .modifier(Entrance(shown: copyShown, step: 0))
                }

                Text(title)
                    .appFont(30, weight: .bold, relativeTo: .largeTitle)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .modifier(Entrance(shown: copyShown, step: 1))

                metaRow
                    .modifier(Entrance(shown: copyShown, step: 2))
            }

            if !genres.isEmpty || ownedLabel != nil {
                genrePills
                    .modifier(Entrance(shown: copyShown, step: 3))
            }
        }
        // Out of the player's way. Quickly, so it's gone before the hero
        // has finished opening; back once it has closed again.
        .opacity(copyHidden ? 0 : 1)
        .animation(copyHidden ? .easeOut(duration: 0.18) : .easeIn(duration: 0.3).delay(0.25),
                   value: copyHidden)
        .allowsHitTesting(!copyHidden)
        // Fades out over the first half of the hero's height as it scrolls
        // away, so it doesn't slide under the nav buttons at full strength.
        .visualEffect { content, geometry in
            let scrolled = max(0, -geometry.frame(in: .scrollView).minY)
            return content.opacity(1 - min(1, scrolled / max(1, geometry.size.height * 0.5)))
        }
        .padding(.horizontal)
        .padding(.top, topInset + 8)
        .padding(.bottom, bottomPadding)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .bottomLeading)
        .background { backdrop }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { heroWidth = $0 }
        .unredacted()
        // Each line carries its own staggered animation (`Entrance`).
        .onAppear { copyShown = true }
        // Scrolling on while it's still loading means the reader wants the
        // page after all: it goes. Once it's playing, it stays.
        .onGeometryChange(for: Bool.self) { proxy in
            proxy.frame(in: .scrollView).minY < -24
        } action: { isScrolled in
            if isScrolled, trailerPhase == .loading { restoreFromTrailer("scrolled") }
        }
        // Off-screen, a trailer the reader is watching pauses — it's only
        // worth its data and battery while someone can see it.
        .onScrollVisibilityChange(threshold: 0.25) { visible in
            heroVisible = visible
            if visible {
                resumeIfPausedByPage("back in view")
            } else if trailerPhase == .watching {
                pauseForPage("scrolled out of view")
            } else {
                restoreFromTrailer("scrolled out of view")
            }
        }
        .onDisappear { restoreFromTrailer("page left") }
        .onChange(of: isCovered) { _, covered in
            if !covered {
                resumeIfPausedByPage("sheet closed")
            } else if trailerPhase == .watching {
                pauseForPage("a sheet came up")
            } else {
                restoreFromTrailer("a sheet came up")
            }
        }
        .onChange(of: trailerActive) { _, active in trailerPlaying.wrappedValue = active }
        .onChange(of: trailerPlaying.wrappedValue) { _, playing in
            if playing {
                playOnRequest()
            } else {
                restoreFromTrailer("closed")
            }
        }
        // Copy set on artwork — past the first accessibility size it would
        // push the actions a screen down. The same text below the fold
        // scales without limit.
        .artworkTypeClamp()
        .accessibilityElement(children: .contain)
    }

    /// Room for the copy — or, once the trailer is on screen, for the whole
    /// player between the nav buttons and the fade into the page, which the
    /// action row overlaps.
    private var minHeight: CGFloat {
        let resting = topInset + 180
        guard trailerUp, heroWidth > 0 else { return resting }
        return max(resting, playerTop + playerSize.height + fadeHeight)
    }

    /// Just under the nav buttons.
    private var playerTop: CGFloat { topInset + 4 }
    /// Full width on a phone; on anything wider, no bigger than reads well
    /// in a header.
    private var playerSize: CGSize {
        let width = min(heroWidth, 720)
        return CGSize(width: width, height: width * 9 / 16)
    }

    // MARK: - Artwork

    private var backdrop: some View {
        ZStack(alignment: .bottom) {
            if trailerUp {
                // While the trailer is up, the backdrop becomes its
                // ambience: the same colours, out of focus and dimmed, for
                // the player's feathered top edge to melt into.
                artworkLayer {
                    RemoteImage(url: artwork?.url, focus: artwork?.focus ?? .center)
                        .blur(radius: 30, opaque: true)
                        .overlay { Color.black.opacity(0.55) }
                }
                .transition(.opacity)
            }

            if trailerUp, let trailerKey {
                trailerLayer(trailerKey)
                    .id(trailerSession)
                    .transition(.opacity)
            }

            // Where the player will be, while it loads.
            if trailerPhase == .loading {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                    .frame(width: max(1, playerSize.width), height: max(1, playerSize.height))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, playerTop)
                    .transition(.opacity)
                    .allowsHitTesting(false)
                    .accessibilityLabel(Text("Loading trailer", comment: "Accessibility: spinner while the trailer loads at the top of the page"))
            }

            // The backdrop itself. Gone quickly when the trailer is asked
            // for, before the hero opening has visibly re-cropped it.
            artworkLayer {
                RemoteImage(url: artwork?.url,
                            focus: artwork?.focus ?? .center,
                            reveal: .focusPull,
                            onLoad: onArtwork) {
                    posterWash
                }
            }
            .opacity(trailerUp ? 0 : 1)
            .animation(trailerUp ? .easeOut(duration: 0.2) : .easeIn(duration: 0.35), value: trailerUp)
            .allowsHitTesting(false)

            // Legibility for the status bar and nav buttons up top.
            LinearGradient(colors: [.black.opacity(0.55), .black.opacity(0.15), .clear],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: topInset + 30)
                .frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)

            // Legibility for the white copy — heavier toward the bottom,
            // where the copy sits. Leaves with the copy when the player
            // takes over. The copy has no shadow of its own: one was redrawn
            // every frame of the copy's entrance, and stuttered it.
            LinearGradient(stops: [.init(color: .clear, location: 0),
                                   .init(color: .black.opacity(0.4), location: 0.45),
                                   .init(color: .black.opacity(0.62), location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .opacity(copyHidden ? 0 : 1)
                .allowsHitTesting(false)

            // Dissolves into the page so the action row grows out of the
            // picture rather than sitting on a seam. Below the player, never
            // over its controls.
            LinearGradient(stops: [.init(color: .clear, location: 0),
                                   .init(color: pageColor.opacity(0.2), location: 0.35),
                                   .init(color: pageColor.opacity(0.65), location: 0.72),
                                   .init(color: pageColor, location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: fadeHeight)
                .allowsHitTesting(false)
        }
        // To the hero's edge as it grows or settles: a layer that arrives
        // mid-animation takes its final size at once, and would otherwise
        // show past the fade until the edge caught up.
        .clipped()
        .stretchy()
        .accessibilityElement(children: .contain)
    }

    /// Fills the hero and drifts on scroll: as the page scrolls up, the
    /// picture moves down a third as far inside its frame — so it trails
    /// the copy instead of leaving with it.
    private func artworkLayer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let parallax = reduceMotion ? 0 : 0.35
        // `Color.clear` takes exactly the hero's size; the image fills it
        // and is clipped to it, whatever the source's aspect ratio.
        return Color.clear
            .overlay {
                content()
                    .visualEffect { content, geometry in
                        let scrolled = max(0, -geometry.frame(in: .scrollView).minY)
                        return content.offset(y: scrolled * parallax)
                    }
            }
            .clipped()
            .accessibilityHidden(true)
    }

    // MARK: - Trailer

    /// The Trailer action, asking for the trailer here.
    private func playOnRequest() {
        guard trailerPhase == .idle else { return }
        guard HeroTrailer.isEnabled, trailerKey != nil, !trailerUnavailable else {
            HeroTrailer.log("can't play it here — opening the full trailer")
            trailerPlaying.wrappedValue = false
            onFullTrailer()
            return
        }
        startTrailer()
    }

    /// The whole 16:9 player just under the nav buttons, its top edge
    /// feathered into the ambience. Hidden behind the spinner while it
    /// loads, then live.
    private func trailerLayer(_ key: String) -> some View {
        let session = trailerSession
        let size = playerSize
        return HeroTrailerView(videoKey: key,
                               interactive: trailerPhase == .watching,
                               remote: trailerRemote,
                               onReady: { trailerDidBecomeReady(session: session) },
                               onPlaying: { trailerDidStartPlaying(session: session) },
                               onEnded: { if session == trailerSession { restoreFromTrailer("ended") } },
                               onFailed: {
                                   trailerUnavailable = true
                                   if session == trailerSession { failTrailer("YouTube refused it") }
                               })
            .frame(width: max(1, size.width), height: max(1, size.height))
            .mask { FeatheredEdges(sides: size.width < heroWidth) }
            .opacity(videoShown ? 1 : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, playerTop)
            .allowsHitTesting(videoShown)
    }

    /// Opens the hero to the player's size, with a spinner where the video
    /// will be, and loads a fresh player there.
    private func startTrailer() {
        guard trailerKey != nil else { return }
        trailerDidPlay = false
        trailerSession += 1
        withAnimation(reduceMotion ? .easeOut(duration: AppMotion.standard) : .spring(response: 0.5, dampingFraction: 0.9)) {
            trailerPhase = .loading
        }
        HeroTrailer.log("loading \(trailerKey ?? "")")

        // A player that never starts — YouTube never answering — mustn't
        // leave the reader waiting forever.
        let session = trailerSession
        Task {
            try? await Task.sleep(for: .seconds(12))
            guard session == trailerSession, trailerPhase == .loading, !trailerDidPlay else { return }
            failTrailer("gave up: the video never started playing")
        }
    }

    /// The player is up and has been asked to play. If it hasn't started
    /// a few seconds on, it isn't going to — the full trailer instead.
    private func trailerDidBecomeReady(session: Int) {
        guard session == trailerSession, trailerPhase == .loading else { return }
        Task {
            try? await Task.sleep(for: .seconds(4))
            guard session == trailerSession, trailerPhase == .loading, !trailerDidPlay else { return }
            failTrailer("gave up: the player was asked to play and didn't")
        }
    }

    private func trailerDidStartPlaying(session: Int) {
        HeroTrailer.log("playing")
        guard session == trailerSession, trailerPhase == .loading else { return }
        trailerDidPlay = true
        Task {
            // A beat for the first frame to land, then the video fades in
            // where the spinner was. Nothing else moves: the hero opened
            // when the reader tapped.
            try? await Task.sleep(for: .seconds(0.3))
            guard session == trailerSession, trailerPhase == .loading else { return }
            withAnimation(.easeInOut(duration: 0.45)) { trailerPhase = .watching }
        }
    }

    /// Pauses for something the page did — and only if it was playing, so a
    /// trailer the reader paused stays paused afterwards.
    private func pauseForPage(_ reason: String) {
        guard trailerRemote.isPlaying else { return }
        pausedByPage = true
        trailerRemote.pause(reason)
    }

    private func resumeIfPausedByPage(_ reason: String) {
        guard pausedByPage, trailerPhase == .watching, heroVisible, !isCovered else { return }
        pausedByPage = false
        trailerRemote.resume(reason)
    }

    /// It couldn't play here: back to the backdrop, and the full trailer
    /// instead.
    private func failTrailer(_ reason: String) {
        restoreFromTrailer(reason)
        onFullTrailer()
    }

    /// Back to the backdrop and the copy; the player fades out and is torn
    /// down, and the hero settles back to its own size.
    private func restoreFromTrailer(_ reason: String) {
        guard trailerPhase != .idle else { return }
        HeroTrailer.log("back to the backdrop: \(reason)")
        pausedByPage = false
        withAnimation(reduceMotion ? .easeOut(duration: AppMotion.standard) : .spring(response: 0.6, dampingFraction: 0.9)) {
            trailerPhase = .idle
        }
    }

    /// The backdrop, or — for a title without one — the poster, cropped
    /// around where key art puts the faces.
    private var artwork: (url: URL, focus: UnitPoint)? {
        if let backdropPath, !backdropPath.isEmpty,
           let url = URL(string: API.Common.imageUrl(imageId: backdropPath, width: .heroBackdrop)) {
            return (url, .center)
        }
        if let url = posterURL {
            return (url, UnitPoint(x: 0.5, y: 0.3))
        }
        return nil
    }

    /// At the URL the lists load it from, so it is almost always already in
    /// memory.
    private var posterURL: URL? {
        guard let posterPath, !posterPath.isEmpty else { return nil }
        return URL(string: API.Common.imageUrl(imageId: posterPath))
    }

    /// What fills the band until the backdrop arrives: the cached poster,
    /// blurred past recognition so only its colours read — a sharp poster
    /// here would look like the wrong picture for a moment.
    @ViewBuilder
    private var posterWash: some View {
        if let posterURL, artwork?.url != posterURL {
            RemoteImage(url: posterURL)
                .blur(radius: 28, opaque: true)
                .scaleEffect(1.2)
        } else {
            Color(.secondarySystemBackground)
        }
    }

    // MARK: - Meta row (★ rating • year • runtime/seasons)

    @ViewBuilder
    private var metaRow: some View {
        let parts = metaParts
        if !parts.isEmpty {
            HStack(spacing: 6) {
                ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                    if index > 0 {
                        Text(verbatim: "•").foregroundStyle(.white.opacity(0.7))
                    }
                    part
                }
            }
            .appFont(14, weight: .medium, relativeTo: .footnote)
            .foregroundStyle(.white.opacity(0.92))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
    }

    private var metaParts: [AnyView] {
        var parts: [AnyView] = []
        if let rating, rating > 0 {
            parts.append(AnyView(
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(RatingStyle.tint(for: rating))
                    Text(rating.ratingText)
                }
            ))
        }
        if let year, !year.isEmpty { parts.append(AnyView(Text(year))) }
        if let runtimeOrSeasons, !runtimeOrSeasons.isEmpty { parts.append(AnyView(Text(runtimeOrSeasons))) }
        // Per episode: the clock says "how long", the seasons beside it
        // say "of what" — together, the size of the commitment.
        if let episodeMinutes, episodeMinutes > 0, let length = Self.duration(minutes: episodeMinutes) {
            parts.append(AnyView(
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .imageScale(.small)
                    Text(length)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Episodes run about \(length)", comment: "Accessibility: typical episode length, e.g. 47m"))
            ))
        }
        if let certification, !certification.isEmpty {
            parts.append(AnyView(
                Text(certification)
                    .appFont(11, weight: .bold, relativeTo: .caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(.white.opacity(0.75), lineWidth: 1)
                    }
                    .accessibilityLabel(Text("Rated \(certification)", comment: "Accessibility: an age rating such as TV-MA"))
            ))
        }
        return parts
    }

    /// "47m", "1h 5m" — abbreviated the way the app's language does it.
    private static func duration(minutes: Int) -> String? {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: TimeInterval(minutes * 60))
    }

    // MARK: - Genre pills

    /// "On your Netflix", "On your Netflix and Max", "On 3 of your
    /// services" — the first thing most people want to know.
    private var ownedLabel: String? {
        switch ownedServices.count {
        case 0:
            return nil
        case 1, 2:
            return String(localized: "On your \(ownedServices.formatted(.list(type: .and)))",
                          comment: "Hero pill: the title streams on the user's own service(s), e.g. On your Netflix")
        default:
            return String(localized: "On \(ownedServices.count) of your services",
                          comment: "Hero pill: the title streams on several of the user's own services")
        }
    }

    private var genrePills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            // One glass container for the row, so the pills are drawn in
            // one pass rather than each on its own.
            GlassGroup(spacing: 8) {
                HStack(spacing: 8) {
                    if let ownedLabel {
                        ServicePill(label: ownedLabel)
                    }
                    ForEach(genres, id: \.self) { genre in
                        GenrePill(name: genre.displayName)
                    }
                }
            }
        }
        // The pills scroll sideways inside a page that scrolls down; without
        // this they'd also clip their own shadow.
        .scrollClipDisabled()
    }
}

/// Display-only genre tag on the artwork. Liquid glass on iOS 26, which
/// adapts to whatever is underneath; `.ultraThinMaterial` before it.
private struct GenrePill: View {
    let name: String

    var body: some View {
        if #available(iOS 26.0, *) {
            Text(name)
                .appFont(12, weight: .semibold, relativeTo: .caption2)
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .glassEffect(.regular, in: Capsule())
        } else {
            Text(name)
                .appFont(12, weight: .semibold, relativeTo: .caption2)
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial.opacity(0.9), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))
        }
    }
}

// MARK: - Covering the page

/// A sheet from somewhere on the details page is up. The page gathers these
/// and tells the hero (`isCovered`), whose trailer pauses for it.
struct CoversDetailsPageKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

extension View {
    /// Tells the details page that a sheet from this view is up — see
    /// `CoversDetailsPageKey`.
    func coversDetailsPage(_ covering: Bool) -> some View {
        preference(key: CoversDetailsPageKey.self, value: covering)
    }
}

// MARK: - Trailer edges

/// The player's mask: fading in over its top few points — out of the
/// ambience under the nav buttons — and at the sides too where it doesn't
/// span the hero. The rest stays sharp: YouTube's controls run along its
/// edges.
private struct FeatheredEdges: View {
    let sides: Bool

    var body: some View {
        let vertical = LinearGradient(stops: [.init(color: .clear, location: 0),
                                              .init(color: .black, location: 0.06)],
                                      startPoint: .top, endPoint: .bottom)
        if sides {
            vertical.mask {
                LinearGradient(stops: [.init(color: .clear, location: 0),
                                       .init(color: .black, location: 0.05),
                                       .init(color: .black, location: 0.95),
                                       .init(color: .clear, location: 1)],
                               startPoint: .leading, endPoint: .trailing)
            }
        } else {
            vertical
        }
    }
}

// MARK: - Entrance

/// One line of the hero copy rising into place, a beat after the line
/// above it.
private struct Entrance: ViewModifier {
    let shown: Bool
    let step: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.82).delay(Double(step) * 0.07),
                       value: shown)
    }
}

/// The pill that leads the genre row when the title streams on one of the
/// user's own services: the accent, so it reads as an answer rather than a
/// tag.
private struct ServicePill: View {
    let label: String

    var body: some View {
        Label(label, systemImage: "play.circle.fill")
            .appFont(12, weight: .bold, relativeTo: .caption2)
            .foregroundStyle(.white)
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(Color.accentColor.opacity(0.9), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
    }
}

