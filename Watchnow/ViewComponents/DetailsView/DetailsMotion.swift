//
//  DetailsMotion.swift
//  Watchnow
//
//  Images and motion shared by the details screen.
//
//  The rule for all of it: motion confirms something — a section arriving,
//  a like landing, a picture coming into focus. Nothing loops, nothing
//  moves while the reader is reading, and with Reduce Motion on every
//  effect here collapses to a plain fade or to nothing.
//

import SwiftUI
import Kingfisher

// MARK: - RemoteImage

/// A Kingfisher-backed image that keeps what it loaded.
///
/// `KFImage` (Kingfisher 6) makes a new loader every time its parent's body
/// runs and ties its identity to it. The details screen re-renders a dozen
/// times while its requests land, so an image that had to *download* could
/// finish on a loader that was no longer on screen — and nothing redrew it
/// until the screen was opened again, from cache. Here the result lives in
/// `@State`, which survives re-renders, and the load is keyed on the URL.
struct RemoteImage<Placeholder: View>: View {

    enum Reveal {
        /// Cross-fade in.
        case fade
        /// Fades in slightly large and settles — a lens finding its frame.
        /// For hero artwork. Scale and fade only: an animated blur over a
        /// picture that size is redrawn every frame, and stuttered the hero
        /// as it came in.
        case focusPull
    }

    let url: URL?
    var contentMode: SwiftUI.ContentMode = .fill
    /// Which part of the picture stays in frame when `.fill` has to crop
    /// it: `.center` trims evenly, `.top` keeps the top edge, and anything
    /// between slides the window proportionally.
    var focus: UnitPoint = .center
    var reveal: Reveal = .fade
    /// Called with the image once it's loaded (or found in the cache).
    var onLoad: ((UIImage) -> Void)? = nil
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var loadedURL: URL?
    @State private var settled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            placeholder()
            if let image, loadedURL == url {
                GeometryReader { geometry in
                    let size = fittedSize(of: image.size, in: geometry.size)
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: size.width, height: size.height)
                        .offset(x: (geometry.size.width - size.width) * focus.x,
                                y: (geometry.size.height - size.height) * focus.y)
                }
                .scaleEffect(settled ? 1 : 1.06)
                .transition(.opacity)
            }
        }
        .task(id: url) { await load() }
    }

    /// The image's size once scaled to fill (or fit) the container.
    private func fittedSize(of image: CGSize, in container: CGSize) -> CGSize {
        guard image.width > 0, image.height > 0 else { return container }
        let widthScale = container.width / image.width
        let heightScale = container.height / image.height
        let scale = contentMode == .fill ? max(widthScale, heightScale) : min(widthScale, heightScale)
        return CGSize(width: image.width * scale, height: image.height * scale)
    }

    private func load() async {
        guard let url else { image = nil; loadedURL = nil; return }

        // Already in memory: show it in this frame, without any reveal — a
        // fade on something that was never missing reads as a flicker.
        if let cached = ImageCache.default.retrieveImageInMemoryCache(forKey: url.absoluteString) {
            settled = true
            image = cached
            loadedURL = url
            onLoad?(cached)
            return
        }

        guard let fetched = await RemoteImageLoader.image(for: url), !Task.isCancelled else { return }
        onLoad?(fetched)

        if reduceMotion {
            image = fetched
            loadedURL = url
            return
        }
        settled = reveal == .fade
        withAnimation(.easeOut(duration: 0.35)) {
            image = fetched
            loadedURL = url
        }
        if reveal == .focusPull {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.9)) {
                settled = true
            }
        }
    }
}

extension RemoteImage where Placeholder == Color {
    init(url: URL?, contentMode: SwiftUI.ContentMode = .fill, focus: UnitPoint = .center, reveal: Reveal = .fade,
         onLoad: ((UIImage) -> Void)? = nil) {
        self.init(url: url, contentMode: contentMode, focus: focus, reveal: reveal, onLoad: onLoad) {
            Color(.secondarySystemBackground)
        }
    }
}

/// Fetches through Kingfisher's shared manager, so these images share the
/// app's memory and disk cache and concurrent requests for one URL share a
/// download.
enum RemoteImageLoader {
    static func image(for url: URL) async -> UIImage? {
        await withCheckedContinuation { continuation in
            KingfisherManager.shared.retrieveImage(with: url, options: [.backgroundDecode]) { result in
                continuation.resume(returning: try? result.get().image)
            }
        }
    }
}

// MARK: - Section arrival

/// How a details section comes in when its data lands.
///
/// Sections are only in the view tree once their request has returned —
/// the cast when the credits do, the providers with the providers — so the
/// transition on insertion *is* "the data arrived". It plays wherever the
/// section is on the page, scrolled to or not; by the time the reader gets
/// there it has settled. `step` staggers sections that arrive in the same
/// update, top to bottom, by a beat each.
///
/// Only the arriving section animates. The page around it doesn't: the
/// `SectionPlaceholder` it replaces already held its room, and a page-wide
/// layout animation is driven frame by frame on the main thread — it made
/// the arrivals stutter.
private struct SectionArrival: ViewModifier {

    let step: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.transition(transition)
    }

    private var transition: AnyTransition {
        if reduceMotion {
            return .opacity.animation(.easeOut(duration: AppMotion.standard))
        }
        let arrive = Animation.spring(response: 0.55, dampingFraction: 0.84)
            .delay(Double(min(step, 6)) * 0.04)
        return .asymmetric(
            insertion: .opacity
                .combined(with: .offset(y: 24))
                .combined(with: .scale(scale: 0.97, anchor: .top))
                .animation(arrive),
            removal: .opacity.animation(.easeOut(duration: AppMotion.exit)))
    }
}

extension View {
    /// See `SectionArrival`.
    func sectionArrival(step: Int = 0) -> some View {
        modifier(SectionArrival(step: step))
    }
}

// MARK: - Section placeholders

/// Stands in for a section while its request is out, in the section's own
/// shape, so the page shows what's coming instead of a gap — and the real
/// section, arriving with `sectionArrival`, replaces something the same
/// size rather than shoving the page down. Gone, quietly, if the request
/// comes back with nothing to show.
struct SectionPlaceholder: View {

    enum Kind {
        /// The one-line "Available on" strip.
        case strip
        /// A few lines of text — the synopsis.
        case text
        /// A full-width card of the given height.
        case card(height: CGFloat)
        /// A heading over a carousel of cards of the given size.
        case carousel(width: CGFloat, height: CGFloat)
    }

    let kind: Kind

    var body: some View {
        InlineShimmerContainer {
            content
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .transition(.opacity)
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .strip:
            ShimmerBox(cornerRadius: AppRadius.hero)
                .frame(height: 58)
                .padding(.horizontal)

        case .text:
            VStack(alignment: .leading, spacing: 9) {
                ForEach(0..<3, id: \.self) { _ in
                    ShimmerBox(cornerRadius: AppRadius.micro).frame(height: 13)
                }
                ShimmerBox(cornerRadius: AppRadius.micro).frame(width: 190, height: 13)
            }
            .padding(.horizontal)

        case .card(let height):
            ShimmerBox(cornerRadius: AppRadius.surface)
                .frame(height: height)
                .padding(.horizontal)

        case .carousel(let width, let height):
            VStack(alignment: .leading, spacing: 14) {
                ShimmerBox(cornerRadius: AppRadius.micro)
                    .frame(width: 110, height: 20)
                // In an overlay, so the row of cards — wider than the
                // screen, like the carousel it stands in for — can't widen
                // the page around it.
                Color.clear
                    .frame(height: height)
                    .overlay(alignment: .leading) {
                        HStack(spacing: 12) {
                            ForEach(0..<4, id: \.self) { _ in
                                ShimmerBox(cornerRadius: AppRadius.panel)
                                    .frame(width: width, height: height)
                            }
                        }
                    }
            }
            .padding(.leading)
        }
    }
}

// MARK: - Bursts

/// A one-shot flourish around a control, played when its state turns on.
struct ToggleBurst: View {

    enum Kind {
        /// Little hearts flung outward — for Like.
        case hearts(Color)
        /// A ring that swells and fades — for Watched.
        case ring(Color)
    }

    let kind: Kind
    /// Plays each time this becomes true.
    let isOn: Bool

    @State private var progress: CGFloat = 0
    @State private var isPlaying = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if isPlaying {
                switch kind {
                case .hearts(let color): hearts(color)
                case .ring(let color):   ring(color)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: isOn) { _, on in
            guard on, !reduceMotion else { return }
            play()
        }
    }

    private func play() {
        progress = 0
        isPlaying = true
        withAnimation(.easeOut(duration: 0.6)) { progress = 1 } completion: {
            isPlaying = false
        }
    }

    private func hearts(_ color: Color) -> some View {
        ForEach(0..<7, id: \.self) { index in
            // Spread over the upper two thirds of a circle, so they spill up
            // and out of the row rather than down into the card below.
            let angle = Angle.degrees(-200 + Double(index) * (220.0 / 6.0))
            let distance = 34 * progress
            Image(systemName: "heart.fill")
                .font(.system(size: index.isMultiple(of: 2) ? 9 : 7, weight: .bold))
                .foregroundStyle(color)
                .offset(x: cos(angle.radians) * distance, y: sin(angle.radians) * distance)
                .scaleEffect(1.2 - progress * 0.6)
                .opacity(Double(1 - progress))
        }
    }

    private func ring(_ color: Color) -> some View {
        Circle()
            .stroke(color, lineWidth: 2)
            .scaleEffect(0.9 + progress * 0.7)
            .opacity(Double(0.7 * (1 - progress)))
    }
}
