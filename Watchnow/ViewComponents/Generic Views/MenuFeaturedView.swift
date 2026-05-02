//
//  MenuFeaturedView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 13/6/23.
//

import SwiftUI
import Kingfisher
import CoreImage

/// Featured hero carousel used on the home and details screens.
///
/// Multi-slide mode renders an Apple-TV-style paging scroll view: rounded
/// cards, peek of the neighbors on each side, and a scale + opacity fade on
/// the non-centered slides. Single-slide mode stays full-bleed (no inset, no
/// rounded corners) so the details-screen hero keeps its cinematic look.
struct MenuFeaturedView<Content: View>: View {
    var results: [Result]
    var overlayContent: (Result) -> Content
    let screenType: ScreenTypes
    /// When `true`, tapping a slide navigates to its details screen. Set to
    /// `false` when this view is *already* the hero of a details screen — in
    /// that case the tap would push a duplicate details view onto itself.
    var isTappable: Bool = true

    /// Seconds each slide dwells before auto-advancing. A user swipe (or a
    /// scene-phase change) restarts this countdown from zero, so viewers
    /// always get a full window to read the slide they just landed on.
    private let slideDwell: Duration = .seconds(6)
    private let dwellSeconds: Double = 6

    // Card treatment — only applied when there is more than one slide.
    private let cardCornerRadius: CGFloat = 20
    private let cardInset: CGFloat = 10      // side padding; drives peek width
    private let cardSpacing: CGFloat = 8

    @State private var scrollIndex: Int? = 0
    @State private var isDragging: Bool = false
    @State private var selectedResult: Result?
    /// Cached dominant tint per slide index. Filled asynchronously when
    /// Kingfisher hands back a decoded `UIImage`; reads cheaply on every
    /// body re-render afterwards.
    @State private var slideTints: [Int: Color] = [:]
    @Environment(\.scenePhase) private var scenePhase

    private var isCarousel: Bool { results.count > 1 }

    var body: some View {
        heroContent
        .stretchy()
        .containerRelativeFrame(.vertical, alignment: .top) { height, _ in height * 0.75 }
        // Note: dragging detection is wired up inside `carouselView` via
        // `onScrollPhaseChange` on the horizontal ScrollView itself, so the
        // hero no longer installs an outer DragGesture. That gesture used
        // to swallow vertical pans, blocking the parent ScrollView from
        // scrolling whenever the user's finger started on the hero.
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
            withAnimation(.easeInOut(duration: 0.5)) {
                scrollIndex = (current + 1) % results.count
            }
        }
        .modifier(TapToNavigateModifier(
            isEnabled: isTappable,
            onTap: {
                let index = scrollIndex ?? 0
                guard results.indices.contains(index) else { return }
                selectedResult = results[index]
            }
        ))
        .navigationDestination(item: $selectedResult) { result in
            let model = ContentDetailsModel(screenType: screenType, result: result)
            let vm = ContentDetailsViewModel(model: model)
            ContentDetailsView(detailsViewModel: vm)
        }
    }

    // Page indicator lives inside the card now — no reserved space needed.
    private let pageIndicatorReserve: CGFloat = 0

    // MARK: - Hero content

    /// Multi-slide uses the Apple-TV-style paging carousel with an ambient
    /// blurred backdrop filling the peek area on both sides. Single-slide
    /// (details-screen hero) takes the direct image path — no ScrollView, no
    /// LazyHStack — so the full-bleed framing matches the original cinematic
    /// look exactly.
    ///
    /// Both branches size against a `GeometryReader`-resolved frame. Relying
    /// on `.aspectRatio(.fill) + .frame(maxHeight: .infinity)` is not
    /// sufficient — the laid-out height drifts past the hero bounds and the
    /// bottom overlay (title / meta / genres) gets pushed onto the primary
    /// action row below.
    @ViewBuilder
    private var heroContent: some View {
        GeometryReader { proxy in
            if isCarousel {
                carouselView(size: proxy.size)
            } else {
                singleSlideView(size: proxy.size)
            }
        }
    }

    // MARK: - Single-slide

    private func singleSlideView(size: CGSize) -> some View {
        getImage(for: 0)
            .aspectRatio(contentMode: .fill)
            .frame(width: size.width, height: size.height)
            .clipped()
            .overlay { overlayContent(results[0]) }
    }

    // MARK: - Carousel

    private func carouselView(size: CGSize) -> some View {
        let cardWidth = size.width - cardInset * 2
        let cardHeight = max(0, size.height - pageIndicatorReserve)

        return ZStack(alignment: .bottom) {
            ambientBackdrop(size: size)

            ScrollView(.horizontal) {
                LazyHStack(spacing: cardSpacing) {
                    ForEach(results.indices, id: \.self) { index in
                        card(for: index, width: cardWidth, height: cardHeight)
                            .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollIndex)
            .safeAreaPadding(.horizontal, cardInset)
            .scrollClipDisabled()
            // `onScrollPhaseChange` observes the inner horizontal scroll
            // *non-intrusively* — it doesn't intercept the gesture, so
            // vertical pans on this view fall through to the parent
            // ScrollView. We only need to know when the carousel is being
            // actively touched/dragged so the auto-advance task pauses.
            .onScrollPhaseChange { _, newPhase in
                isDragging = (newPhase == .interacting || newPhase == .tracking)
            }
            .frame(width: size.width, height: size.height)
            // Indicator sits inside the card, above the spotlight overlay
            .overlay(alignment: .bottom) {
                pageIndicator
            }
        }
    }

    private func card(for index: Int, width: CGFloat, height: CGFloat) -> some View {
        getImage(for: index)
            .aspectRatio(contentMode: .fill)
            .frame(width: width, height: height)
            .clipped()
            .overlay { overlayContent(results[index]) }
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
            // compositingGroup() flattens the card + shadow into a single
            // layer before scrollTransition applies opacity. Without it the
            // shadow renders at full strength even when the card is faded,
            // producing a ghost artefact behind transitioning slides.
            .compositingGroup()
            .shadow(color: .black.opacity(0.35), radius: 6, y: 10)
            .scrollTransition(axis: .horizontal) { content, phase in
                content
                    .scaleEffect(phase.isIdentity ? 1.0 : 0.9)
                    .opacity(phase.isIdentity ? 1.0 : 0.45)
            }
    }

    // MARK: - Ambient backdrop
    //
    // Heavily blurred copy of the current slide's image filling the whole
    // hero. Fills the peek gutters left/right of the centered card (and the
    // strip under the card reserved for the page indicator) with color that
    // tracks the active slide — same trick Apple TV and Apple Music use to
    // make the hero feel less empty.
    //
    // Two `.frame(…).clipped()` passes are deliberate: the first contains
    // the aspect-fill overflow before blurring, the second contains the
    // blur halo (which otherwise extends ~45pt beyond the hero and lands on
    // top of the "🔥 Hot Right Now" section header stacked directly below).

    private func ambientBackdrop(size: CGSize) -> some View {
        let safeIndex = min(max(scrollIndex ?? 0, 0), results.count - 1)
        let tint = slideTints[safeIndex] ?? .black

        return KFImage.url(results[safeIndex].getResultPosterURL())
            .onSuccess { result in
                // Dominant-tint extraction runs off the main actor because
                // CIAreaAverage + context render is blocking; pushing it to
                // a detached task keeps the carousel snappy during swipes.
                cacheTintIfNeeded(for: safeIndex, image: result.image)
            }
            .loadImmediately()
            .fromMemoryCacheOrRefresh()
            .cacheOriginalImage()
            .fade(duration: 0.35)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size.width, height: size.height)
            .clipped()
            .blur(radius: 45)
            // Colour wash pulled from the slide itself — same trick Spotify
            // and Apple Music use on "Now Playing" backgrounds, but layered
            // over the blurred poster (not replacing it) so the texture of
            // the image still shows through the tint.
            .overlay(tint.opacity(0.45))
            .overlay(Color.black.opacity(0.25))
            // Left edge vignette — fades the backdrop into darkness at the
            // card's left boundary so the gap between card and backdrop reads
            // as a smooth darkening rather than a hard image edge / seam line.
            .overlay(alignment: .leading) {
                LinearGradient(
                    colors: [.black.opacity(0.75), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: cardInset + 14)
                .allowsHitTesting(false)
            }
            // Right edge vignette — mirrors the left treatment.
            .overlay(alignment: .trailing) {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.75)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: cardInset + 14)
                .allowsHitTesting(false)
            }
            // Top scrim — the ambient backdrop bleeds behind the nav bar and
            // status bar. A soft top-to-transparent vignette keeps system UI
            // legible over whatever colour the backdrop happens to be.
            .overlay(alignment: .top) {
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.55), location: 0.0),
                        .init(color: .black.opacity(0.15), location: 0.5),
                        .init(color: .clear,               location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
                .allowsHitTesting(false)
            }
            // Bottom fader — dissolves the tinted ambient backdrop into the
            // app's scroll background, so the first section below the hero
            // (e.g. "Trending Movies") grows out of the tint rather than
            // starting after a tinted-to-base-bg tone cut. Eased over four
            // stops to avoid a perceptible ramp line.
            .overlay(alignment: .bottom) {
                LinearGradient(
                    stops: [
                        .init(color: .clear,                               location: 0.0),
                        .init(color: Color(.background).opacity(0.18),     location: 0.35),
                        .init(color: Color(.background).opacity(0.6),      location: 0.72),
                        .init(color: Color(.background),                   location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 90)
                .allowsHitTesting(false)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.45), value: tint)
            .animation(.easeInOut(duration: 0.35), value: safeIndex)
    }

    /// Computes a hero tint from the decoded poster once per slide and
    /// memoizes it in `slideTints`. Image decoding already happened on
    /// Kingfisher's worker; we still push the CoreImage average render
    /// off the main actor because it's blocking.
    private func cacheTintIfNeeded(for index: Int, image: UIImage) {
        guard slideTints[index] == nil else { return }
        Task.detached(priority: .userInitiated) {
            let uiColor = image.heroTint
            guard let uiColor else { return }
            await MainActor.run {
                slideTints[index] = Color(uiColor)
            }
        }
    }

    // MARK: - Page indicator

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(results.indices, id: \.self) { index in
                let isActive = index == (scrollIndex ?? 0)
                Group {
                    if isActive {
                        ProgressCapsule(duration: dwellSeconds)
                    } else {
                        Capsule()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: 6, height: 6)
                    }
                }
                // Force recreation when a dot transitions active ↔ inactive
                // so ProgressCapsule's .onAppear always fires on a fresh view.
                .id("\(index)-\(isActive)")
                .animation(.easeInOut(duration: 0.25), value: scrollIndex)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.bottom, 18)
    }

    // MARK: - Progress capsule

    /// A 28 × 6 pt capsule that fills left-to-right over `duration` seconds.
    ///
    /// Two gotchas the animation has to survive:
    /// 1. On reappear, `progress` may still be at 1.0 from a previous cycle.
    ///    A naive `withAnimation { progress = 1.0 }` sees no state change and
    ///    skips the animation entirely — the fill appears instantly full.
    /// 2. While the app is backgrounded, SwiftUI snaps in-flight animations
    ///    to their final state. When the app returns to `.active`, the parent
    ///    carousel's auto-advance `.task` restarts with a fresh `dwellSeconds`
    ///    wait, but this view isn't recreated, so without intervention the
    ///    capsule stays stuck at full for the next dwell.
    ///
    /// The fix: reset `progress` to 0 inside a transaction with animations
    /// disabled, then start the linear fill on the next runloop tick so the
    /// reset has committed before the animated change is read. `scenePhase`
    /// observation retriggers the same reset-then-animate cycle on resume.
    private struct ProgressCapsule: View {
        let duration: Double
        @State private var progress: CGFloat = 0
        @Environment(\.scenePhase) private var scenePhase

        var body: some View {
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 28, height: 6)
                // Animated fill
                Capsule()
                    .fill(Color.white.opacity(0.95))
                    .frame(width: 28, height: 6)
                    .scaleEffect(x: progress, anchor: .leading)
            }
            .frame(width: 28, height: 6)
            .clipShape(Capsule())
            .onAppear { restartAnimation() }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    restartAnimation()
                }
            }
        }

        private func restartAnimation() {
            // Snap back to 0 with animations explicitly disabled so the
            // reset is instantaneous, not part of the previous animation.
            var resetTx = Transaction()
            resetTx.disablesAnimations = true
            withTransaction(resetTx) {
                progress = 0
            }
            // Defer the animated change to the next runloop tick so SwiftUI
            // commits the reset first. Without this, both mutations coalesce
            // and the animation starts from whatever `progress` was before,
            // not from 0.
            DispatchQueue.main.async {
                withAnimation(.linear(duration: duration)) {
                    progress = 1.0
                }
            }
        }
    }

    // MARK: - Auto-advance plumbing

    /// Composite key that drives the `.task` restart — every dimension that
    /// should reset the dwell timer belongs here.
    private var autoAdvanceKey: AutoAdvanceKey {
        AutoAdvanceKey(tab: scrollIndex ?? 0,
                       isActive: scenePhase == .active,
                       isDragging: isDragging,
                       slideCount: results.count)
    }

    private var shouldAutoAdvance: Bool {
        scenePhase == .active && !isDragging && isCarousel
    }

    private struct AutoAdvanceKey: Equatable {
        let tab: Int
        let isActive: Bool
        let isDragging: Bool
        let slideCount: Int
    }

    // MARK: - Image

    func getImage(for index: Int) -> some View {
        KFImage.url(results[index].getResultPosterURL())
            .placeholder {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .loadImmediately()
            .loadDiskFileSynchronously()
            .fromMemoryCacheOrRefresh()
            .cacheOriginalImage()
            .fade(duration: 0.25)
            .resizable()
            .tag(index)
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
// Colour-sampling helper used by `ambientBackdrop` so the blurred poster
// can be tinted with its own dominant hue — same trick Spotify and
// Apple Music use on "Now Playing" backgrounds. Lives in this file
// (rather than a standalone helper) so no Xcode project wiring is
// needed to pick it up; only `MenuFeaturedView` consumes it today.

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
    fileprivate var heroTint: UIColor? {
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
