//
//  MovieCoachView.swift
//  Watchnow
//
//  The Movie Coach card on the details screen: a short, personal read on
//  whether this title is a good choice for *this* user right now.
//
//  Behaviour that matters:
//   - It never blocks the details screen. The card only appears once the
//     screen's own fetches have settled, and generation happens in a
//     `.task(id:)` that SwiftUI cancels automatically on disappear.
//   - Keyed on the context signature, so exactly one generation runs per
//     title (not one per fetch completing) and re-opening a title reuses the
//     cached answer instantly.
//   - If Foundation Models isn't available on this device, the whole section
//     renders as nothing — no placeholder, no apology.
//

import SwiftUI

struct MovieCoachView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion


    /// Nil until the details screen has finished loading the data Coach
    /// reads. Passing nil keeps the card in its loading state.
    let context: MovieCoachContext?

    @State private var answer: MovieCoachAnswer?
    @State private var isGenerating = false
    @State private var didFail = false
    @State private var showAsk = false

    var body: some View {
        // Hidden entirely on devices/OS versions without on-device models.
        if MovieCoachService.isReady {
            Group {
                if MovieCoachService.hasEnoughHistory {
                    card
                } else {
                    // Not enough taste history yet — say so plainly
                    // rather than offering a guess.
                    warmUpHint
                }
            }
            .padding(.horizontal)
            .task(id: context?.signature) {
                await load()
            }
        }
    }

    /// Small attribution line inside the card. The section header used to sit
    /// above it saying "Movie Coach" — which was both wrong on a series and a
    /// waste of the most valuable line on the card. The verdict gets that
    /// space now; the feature name shrinks to an eyebrow.
    private var eyebrow: some View {
        HStack(spacing: 5) {
            Image(systemName: "sparkles")
                .appFont(10, weight: .bold, relativeTo: .caption2)
            Text("COACH")
                .appFont(11, weight: .heavy, relativeTo: .caption2, design: .rounded)
                .tracking(1.1)
        }
        .foregroundStyle(Color.accentColor)
    }

    // MARK: - Warm-up hint

    /// Shown until the watchlist reaches `minimumWatchlistSize`. Frames the
    /// threshold as progress rather than a lockout.
    private var warmUpHint: some View {
        let saved = MovieCoachService.savedTitleCount
        let target = MovieCoachService.minimumWatchlistSize
        let remaining = max(0, target - saved)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                eyebrow
                Spacer(minLength: 0)
                Text("🎬").appFont(26, relativeTo: .title).accessibilityHidden(true)
            }

            Text("Getting to know your taste")
                .appFont(20, weight: .heavy, relativeTo: .title3)
                .foregroundStyle(.primary)

            Text("Save \(remaining) more \(remaining == 1 ? "title" : "titles") to your watchlist and Movie Coach will start telling you whether something's a good fit for you.")
                .appFont(14, relativeTo: .subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ProgressView(value: Double(saved), total: Double(target))
                    .tint(Color.accentColor)
                Text("\(saved) of \(target)")
                    .appFont(12, weight: .semibold, relativeTo: .caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .modifier(CoachCardSurface(prominence: .quiet))
    }

    // MARK: - Card

    @ViewBuilder
    private var card: some View {
        let prominence = answer?.verdict.prominence ?? .quiet

        VStack(alignment: .leading, spacing: 14) {
            if let answer {
                verdictBlock(answer)

                Text(answer.message)
                    .appFont(15, relativeTo: .subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(1.5)

                Divider().overlay(Color.primary.opacity(0.08))

                askRow
            } else if didFail {
                eyebrow
                failureRow
            } else {
                eyebrow
                skeleton
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .modifier(CoachCardSurface(prominence: prominence))
        .animation(reduceMotion ? nil : .easeInOut(duration: AppMotion.standard), value: answer)
        .animation(reduceMotion ? nil : .easeInOut(duration: AppMotion.standard), value: didFail)
        .sheet(isPresented: $showAsk) {
            if let context {
                MovieCoachAskSheet(context: context)
            }
        }
    }

    /// The whole point of the feature, sized like it.
    private func verdictBlock(_ answer: MovieCoachAnswer) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                eyebrow
                Spacer(minLength: 0)
                Text(answer.verdict.emoji)
                    .appFont(30, relativeTo: .title)
                    .accessibilityHidden(true)
            }

            Text(answer.verdict.headline)
                .appFont(26, weight: .heavy, relativeTo: .title)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text(answer.verdict.subhead)
                .appFont(14, weight: .semibold, relativeTo: .subheadline)
                .foregroundStyle(Color.accentColor)
        }
    }

    private var askRow: some View {
        HStack(spacing: 14) {
            Button {
                showAsk = true
            } label: {
                Label("Ask Coach", systemImage: "bubble.left.and.text.bubble.right")
                    .appFont(14, weight: .semibold, relativeTo: .subheadline)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(context == nil)

            Spacer(minLength: 0)

            Button {
                Task { await regenerate() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .appFont(13, weight: .semibold, relativeTo: .footnote)
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ask Coach again")
        }
    }

    private var failureRow: some View {
        HStack(spacing: 10) {
            Text("Couldn't get a read on this one.")
                .appFont(14, relativeTo: .subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button("Retry") { Task { await regenerate() } }
                .appFont(13, weight: .semibold, relativeTo: .footnote)
                .foregroundStyle(Color.accentColor)
                .buttonStyle(.plain)
        }
    }

    /// Redacted stand-in that matches the real card's shape, so nothing
    /// jumps when the answer lands.
    private var skeleton: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Great pick")
                .appFont(15, weight: .bold, relativeTo: .subheadline)
            Text("Checking whether this is a good match for you right now and how it fits your evening.")
                .appFont(14, relativeTo: .subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .redacted(reason: .placeholder)
    }

    // MARK: - Generation

    private func load() async {
        guard let context else { return }

        // Refresh TMDB's "also liked" graph in the background — weekly at
        // most, and entirely optional to the verdict.
        Task { await TasteProfile.rebuildGraphIfNeeded(using: ServiceInvocation()) }

        // Nothing to generate while the warm-up hint is showing.
        guard MovieCoachService.isReady, MovieCoachService.hasEnoughHistory else { return }

        let key = MovieCoachCache.key(mediaType: context.kind, id: String(context.tmdbID))
        if let cached = MovieCoachCache.read(key: key, signature: context.signature) {
            answer = cached
            didFail = false
            return
        }
        await generate(context: context, key: key)
    }

    private func regenerate() async {
        guard let context else { return }
        let key = MovieCoachCache.key(mediaType: context.kind, id: String(context.tmdbID))
        MovieCoachCache.invalidate(key: key)
        answer = nil
        await generate(context: context, key: key)
    }

    private func generate(context: MovieCoachContext, key: String) async {
        guard !isGenerating else { return }
        isGenerating = true
        didFail = false
        defer { isGenerating = false }

        do {
            let generated = try await MovieCoachService.verdict(for: context)
            guard !Task.isCancelled else { return }
            answer = generated
            MovieCoachCache.write(generated, key: key, signature: context.signature)
        } catch {
            #if DEBUG
            print("[MovieCoach] generation failed: \(error)")
            #endif
            guard !Task.isCancelled else { return }
            didFail = true
        }
    }
}

// MARK: - Card surface

/// Glass surface for the Coach card, plus the rotating spectrum edge that
/// marks it as the intelligence feature.
///
/// Follows the same iOS 26 / fallback split as `ActionPillBackground`:
/// liquid glass where it exists, material + fill below. Confidence is carried
/// by how strongly the glass is tinted, so the palette stays accent-only —
/// the moving border is the one deliberate exception, and it earns it by
/// saying "a model wrote this" rather than by decorating.
private struct CoachCardSurface: ViewModifier {

    let prominence: MovieCoachVerdict.Prominence
    private let radius: CGFloat = 20

    func body(content: Content) -> some View {
        surface(content)
            // Behind the glass, not on top of it. The material samples its
            // backdrop, so the glow gets refracted and diffused through the
            // card instead of sitting on the surface as a drawn-on ring —
            // which is what makes it read as lit from within. Boosted a
            // little because the glass eats some of the intensity.
            // Big, soft light source *behind* the glass — this is what the
            // material picks up and diffuses through the card.
            .background {
                IntelligenceBorder(cornerRadius: radius,
                                   opacity: glowOpacity,
                                   thickness: glowThickness,
                                   blurRadius: 11)
            }
            // A hairline of the same gradient *on top*, so the card still has
            // a defined edge. Diffused light alone reads as a smudge; this
            // gives it a crisp outline to sit inside.
            .overlay {
                IntelligenceBorder(cornerRadius: radius,
                                   opacity: 0.85,
                                   thickness: 1.4,
                                   blurRadius: 0.4,
                                   masked: false)
            }
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }

    /// Plain solid card, matching the other surfaces on the details screen.
    /// The glow lives behind it and reads as a rim around the edge rather
    /// than light shining through the panel.
    private func surface(_ content: Content) -> some View {
        content.background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        }
    }

    /// Confidence now rides on how brightly the card is lit from behind,
    /// rather than on how strongly its surface is tinted.
    private var glowOpacity: Double {
        switch prominence {
        case .loud:   return 0.70
        case .tinted: return 0.55
        case .quiet:  return 0.40
        }
    }

    private var glowThickness: CGFloat {
        switch prominence {
        case .loud:   return 8
        case .tinted: return 6
        case .quiet:  return 5
        }
    }
}

/// The Siri / Apple-Intelligence edge glow.
///
/// The character of that effect isn't a spinning rainbow — it's a soft bloom
/// hugging the edge whose *thickness varies organically* around the
/// perimeter: fat magenta in one corner, a thin blue stretch opposite, warm
/// amber pooling somewhere else. It drifts slowly rather than racing.
///
/// How that's built here:
///  - The gradient's stops vary in **opacity as well as hue**. Blurred, a
///    full-opacity arc blooms wide while a 30%-opacity one stays a whisper —
///    that difference is what reads as uneven thickness. A uniform
///    `lineWidth` alone can never produce it.
///  - The gradient is applied *as the stroke of the card's own shape*, and
///    rotated via the gradient's `angle:` rather than a `rotationEffect`.
///    An earlier attempt rasterised a blurred gradient with `.drawingGroup()`
///    and rotated that layer — the cached layer's bounds stopped matching the
///    card, so the mask clipped the wrong rectangle and the "glow" came out
///    as two neon bars above and below the card. Stroking the real shape
///    can't drift out of alignment.
private struct IntelligenceBorder: View {

    let cornerRadius: CGFloat
    var opacity: Double = 1.0
    /// Geometric stroke width; the blur and the gradient's opacity swings do
    /// the rest of the sculpting.
    var thickness: CGFloat = 10
    /// Blur applied to the glow. Generous behind the glass — the material
    /// diffuses whatever sits under it, so a thin source simply disappears —
    /// and near-zero for the crisp edge drawn on top.
    var blurRadius: CGFloat = 9
    /// Confine the glow to a band around the edge. Off for the thin edge
    /// pass, which is already only as wide as its own stroke.
    var masked: Bool = true

    /// One slow lap. Siri's glow drifts — it doesn't chase.
    private let lapDuration: Double = 16

    @State private var phase: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let magenta = Color(red: 1.00, green: 0.24, blue: 0.62)
    private static let purple  = Color(red: 0.66, green: 0.33, blue: 1.00)
    private static let blue    = Color(red: 0.28, green: 0.55, blue: 1.00)
    private static let amber   = Color(red: 1.00, green: 0.62, blue: 0.25)

    /// Uneven on purpose — the opacity swings are what sculpt the thickness.
    private var stops: [Gradient.Stop] {
        [
            .init(color: Self.magenta,               location: 0.00),
            .init(color: Self.magenta.opacity(0.95), location: 0.10),
            .init(color: Self.purple.opacity(0.55),  location: 0.22),
            .init(color: Self.blue.opacity(0.30),    location: 0.34),
            .init(color: Self.blue.opacity(0.85),    location: 0.46),
            .init(color: Self.purple.opacity(0.40),  location: 0.58),
            .init(color: Self.amber.opacity(1.00),   location: 0.70),
            .init(color: Self.amber.opacity(0.45),   location: 0.80),
            .init(color: Self.magenta.opacity(0.75), location: 0.90),
            .init(color: Self.magenta,               location: 1.00)
        ]
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        // The gradient is built **without** an angle and rotated as a view.
        //
        // Feeding `phase` into `AngularGradient(angle:)` meant the gradient —
        // and every blur applied over it — was re-rendered on every frame.
        // Blur is an offscreen pass, so at 60fps alongside a scrolling
        // ScrollView that was enough to visibly stutter the whole details
        // screen. Here the blurred gradient is rasterised once by
        // `drawingGroup()` and the animation only spins that cached texture,
        // which is a GPU transform and effectively free.
        GeometryReader { geo in
            let side = max(geo.size.width, geo.size.height) * 1.6
            AngularGradient(gradient: Gradient(stops: stops), center: .center)
                .frame(width: side, height: side)
                .blur(radius: blurRadius)
                .drawingGroup()
                .rotationEffect(.degrees(phase))
                // Collapse back to the card's box so the mask below lines up
                // with the card and not with the rotated layer's bounds —
                // getting this wrong previously produced neon bars floating
                // above and below the card.
                //
                // Deliberately *not* `.clipped()`: that clips to a rectangle,
                // so anywhere the blurred mask reached past a rounded corner
                // it exposed the square bounding box and the glow came out
                // with visible straight corners. The mask below is already a
                // rounded stroke, so it's the only clip needed.
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .mask(
            masked
            // A narrow band keeps the light on the rim. Wider than ~2× and it
            // reaches the middle of the card, leaving the body copy sitting
            // on a magenta wash.
            ? AnyView(shape.strokeBorder(lineWidth: thickness * 2).blur(radius: blurRadius))
            // Crisp hairline pass — its own stroke is already the full extent.
            : AnyView(shape.strokeBorder(lineWidth: thickness))
        )
        .opacity(opacity)
        .allowsHitTesting(false)
        .onAppear {
            // The rim light is a flourish on a card the user is reading. It
            // laps forever, so Reduce Motion parks it — the border stays,
            // it just stops travelling.
            guard !reduceMotion else { return }
            withAnimation(reduceMotion ? nil : .linear(duration: lapDuration).repeatForever(autoreverses: false)) {
                phase = 360
            }
        }
    }
}
