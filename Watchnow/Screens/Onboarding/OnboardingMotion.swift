//
//  OnboardingMotion.swift
//  Watchnow
//
//  The motion vocabulary for the first run.
//
//  Onboarding is the one screen every new user sees and most of them see
//  only once, so it is worth moving. The rule throughout is that motion
//  should explain something: the grid cascades so the eye is led through it
//  rather than dumped in front of it, steps push sideways so advancing has
//  a direction, and the finish screen deals the saved covers like cards
//  because that is the payoff the whole flow was building to.
//
//  The one exception is the poster wall, which moves for its own sake. An
//  app about films that opens on a flat colour is an app that could be
//  about anything, and a wall of real artwork drifting behind the questions
//  says what the product is before a word of copy has been read.
//
//  Every effect here checks Reduce Motion and collapses to a plain
//  cross-fade — never to nothing, because an element that appears with no
//  transition at all reads as a glitch.
//

import SwiftUI

// MARK: - Staggered reveal

/// Fades and lifts an item into place, delayed by its position.
///
/// The delay is capped rather than linear in the index: thirty posters at
/// 30ms each would take nearly a second to finish, by which point the user
/// has started reading and the last row arriving is a distraction rather
/// than a flourish.
///
/// Tighter than it used to be, because the cascade no longer starts when
/// the step mounts — it starts once the push has landed (see
/// `OnboardingView.arm`). The two run back to back now rather than on top
/// of each other, so the budget for the cascade alone is smaller.
struct StaggeredReveal: ViewModifier {

    let index: Int
    let isRevealed: Bool
    let reduceMotion: Bool

    private static let step: Double = 0.022
    private static let maximumDelay: Double = 0.26

    private var delay: Double { min(Double(index) * Self.step, Self.maximumDelay) }

    func body(content: Content) -> some View {
        content
            .opacity(isRevealed ? 1 : 0)
            .scaleEffect(isRevealed || reduceMotion ? 1 : 0.9)
            .offset(y: isRevealed || reduceMotion ? 0 : 16)
            .animation(reduceMotion
                       ? .easeOut(duration: AppMotion.standard)
                       : .spring(response: 0.46, dampingFraction: 0.78).delay(delay),
                       value: isRevealed)
    }
}

extension View {
    func staggeredReveal(index: Int, isRevealed: Bool, reduceMotion: Bool) -> some View {
        modifier(StaggeredReveal(index: index, isRevealed: isRevealed, reduceMotion: reduceMotion))
    }
}

// MARK: - Cinematic push

/// The four values a step is pushed through on its way in or out.
struct CinematicPush: ViewModifier {

    let dx: CGFloat
    let scale: CGFloat
    let blur: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .offset(x: dx)
            .blur(radius: blur)
            .opacity(opacity)
    }
}

extension AnyTransition {

    /// One step sliding out to the left while the next arrives from the
    /// right, the outgoing one receding and softening as it goes.
    ///
    /// A directional slide was tried once before and abandoned, and the
    /// reason it failed is worth recording because the fix is the whole
    /// design here: the step's content is a thirty-item `LazyVGrid` whose
    /// cells were cascading in *at the same time* as the container slid, so
    /// posters ended up scattered mid-flight with their captions detached.
    /// Running the two in sequence instead — push, land, then cascade —
    /// costs about 200ms and turns the same two effects into a shot rather
    /// than a collision.
    ///
    /// The blur is the one offscreen render pass in this file, and it is
    /// affordable for a specific reason: it only ever applies to the
    /// *outgoing* view, for the ~250ms it takes to leave, four times in the
    /// whole flow. Nothing here blurs while the user is scrolling, which is
    /// the case that actually costs frames.
    static func cinematicPush(reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        // The travel is large relative to the scale on purpose. A first pass
        // used ±50pt against a 0.92/1.06 scale pair and the recorded frames
        // read as a zoom with a blur on it — both views were moving mostly
        // *towards the viewer*, and the sideways component never registered.
        // Roughly a quarter of the screen's width each way, with the scale
        // pulled in to a hint of depth, is what makes it a push.
        return .asymmetric(
            insertion: .modifier(
                active:   CinematicPush(dx: 110, scale: 1.03, blur: 0, opacity: 0),
                identity: CinematicPush(dx: 0,   scale: 1,    blur: 0, opacity: 1)),
            removal: .modifier(
                active:   CinematicPush(dx: -84, scale: 0.95, blur: 6, opacity: 0),
                identity: CinematicPush(dx: 0,   scale: 1,    blur: 0, opacity: 1)))
    }
}

// MARK: - Surface

/// The one pane style everything in the flow sits on.
///
/// Shared rather than written out at each call site because it has to be
/// tuned against the *worst* frame of the wall, not a typical one. The
/// first attempt was `Color.white.opacity(0.07)` — a sheen, which is what
/// glass looks like over a photograph that is holding still. Over drifting
/// artwork it disappeared entirely, and a row of service chips ended up
/// sitting on a full-brightness Simpsons poster.
///
/// So: a dark pane with a sheen mixed into it, at the single alpha that
/// composites to the same result as black-then-white in two layers. Text
/// stays crisp over any cover the wall can put behind it, and the drift is
/// still visible through it, which is the whole reason it isn't opaque.
enum OnboardingSurface {
    static let glass = Color(white: 0.12).opacity(0.58)
    static let edge = Color.white.opacity(0.16)
}

// MARK: - Poster wall

/// Four rows of real poster art, tilted off-axis and drifting past each
/// other behind the whole flow.
///
/// This replaces the pair of blurred colour blobs that used to sit here.
/// They were set at 0.11 and 0.06 alpha over a near-white background, which
/// on a device is indistinguishable from nothing — the screen read as
/// static, and static is the one thing a first impression cannot be.
///
/// Reuses `DriftRow` from the search screen rather than reimplementing it,
/// which matters for one specific reason: its position is a pure function
/// of wall-clock time from a shared static epoch, so the wall is never seen
/// to start. It is already mid-glide on the first frame of the first
/// launch, and it stays in phase across every step change.
struct PosterWall: View {

    let posters: [URL]
    /// How hard to hold the artwork back on this step. The question steps
    /// push it right down — a wall of posters behind a grid of posters is
    /// two things competing to be looked at — and the welcome and payoff
    /// screens let it come up, because there they *are* the screen.
    let dim: Double
    /// Shifts sideways as the flow advances, at a fraction of the step's
    /// own travel, so the background reads as further away.
    let parallax: CGFloat
    let reduceMotion: Bool

    private static let rowCount = 4
    /// Deliberately not multiples of each other: rows on harmonically
    /// related speeds drift back into alignment every so often and
    /// momentarily read as one sliding sheet.
    private static let speeds: [CGFloat] = [9, 14, 7, 11]

    private static let posterWidth: CGFloat = 110
    private static let posterHeight: CGFloat = 165

    /// Dealt round-robin so neighbouring rows never show the same cover
    /// twice in a line.
    private var rows: [[URL]] {
        guard !posters.isEmpty else { return [] }
        var out = [[URL]](repeating: [], count: Self.rowCount)
        for (index, url) in posters.enumerated() { out[index % Self.rowCount].append(url) }
        return out
    }

    var body: some View {
        ZStack {
            // Under everything, so a cold cache or a failed fetch leaves a
            // finished-looking screen rather than a hole. The launch
            // screen's *dark* ramp specifically: this flow forces a dark
            // appearance regardless of the system setting, so the light
            // ramp — which is what the icon itself is painted on — would be
            // a near-white slab behind a black scrim.
            WatchnowBrand.launchGradientDark

            // `rowCount`, not one: the rows are dealt round-robin, so any
            // shorter list leaves empty rows — and `DriftRow` reads an
            // empty list as "still loading" and draws its shimmer
            // placeholder, which on this backdrop is rows of grey boxes
            // drifting behind the content. Below that threshold the launch
            // gradient alone is the honest, finished-looking answer.
            if posters.count >= Self.rowCount { wall }

            scrim
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var wall: some View {
        VStack(spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                DriftRow(posters: row,
                         reversed: index.isMultiple(of: 2),
                         speed: Self.speeds[index % Self.speeds.count],
                         reduceMotion: reduceMotion,
                         posterWidth: Self.posterWidth,
                         posterHeight: Self.posterHeight,
                         spacing: 10,
                         cornerRadius: AppRadius.card,
                         // Five slots is 600pt per copy against a 402pt
                         // phone, with room for the tilt to eat into.
                         minimumSlots: 5)
            }
        }
        // Both are render transforms, so the rows still lay out at the
        // screen's own width — the tilt and the overscale cost nothing in
        // layout terms, and between them they guarantee no edge of the
        // grid is ever in frame.
        .rotationEffect(.degrees(-12))
        .scaleEffect(1.34)
        .offset(x: parallax)
    }

    /// Three layers, because one flat wash cannot do all three jobs: hold
    /// the art back by the right amount for this step, guarantee contrast
    /// under the header and the button specifically, and keep the corners
    /// from lifting off the frame.
    private var scrim: some View {
        ZStack {
            Color.black.opacity(dim)

            // Ramped hard at both ends rather than evenly, because both
            // ends carry controls: the rail and the header at the top, the
            // primary button and Skip at the bottom. The middle is the only
            // band allowed to be bright, and only on the steps whose `dim`
            // lets it.
            LinearGradient(stops: [
                .init(color: .black.opacity(0.92), location: 0.00),
                .init(color: .black.opacity(0.62), location: 0.11),
                .init(color: .black.opacity(0.34), location: 0.30),
                .init(color: .black.opacity(0.38), location: 0.52),
                .init(color: .black.opacity(0.78), location: 0.80),
                .init(color: .black.opacity(0.97), location: 1.00),
            ], startPoint: .top, endPoint: .bottom)

            RadialGradient(colors: [.clear, .black.opacity(0.55)],
                           center: .center, startRadius: 150, endRadius: 520)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.55), value: dim)
    }
}

// MARK: - Breathing

/// A slow rise and fall that never stops.
///
/// Its own view modifier with its own `@State` so the loop is owned by the
/// thing that loops — a `repeatForever` started from a parent that
/// re-renders (and the welcome screen re-renders as the wall's artwork
/// arrives) gets torn down and restarted each time, which reads as a hitch.
struct Breathing: ViewModifier {

    let reduceMotion: Bool
    var travel: CGFloat = 8
    var period: Double = 3.6

    @State private var raised = false

    func body(content: Content) -> some View {
        content
            .offset(y: raised ? -travel : travel)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: period).repeatForever(autoreverses: true)) {
                    raised = true
                }
            }
    }
}

extension View {
    func breathing(reduceMotion: Bool, travel: CGFloat = 8, period: Double = 3.6) -> some View {
        modifier(Breathing(reduceMotion: reduceMotion, travel: travel, period: period))
    }
}

// MARK: - Shine

/// A highlight that sweeps across the primary button, on a loop with a rest
/// in it.
///
/// The rest is what keeps it from being a tic. The phase travels well past
/// the trailing edge before wrapping, so the band is only actually on the
/// button for about the first third of each cycle and the rest of the time
/// it is off-screen — one linear animation, no timer, no second timeline.
///
/// `UnitPoint` values outside 0…1 are valid and place the gradient's stops
/// beyond the shape's bounds, which is the same trick `ShimmerBox` uses.
struct Shine: ViewModifier {

    let isActive: Bool
    let reduceMotion: Bool
    let shape: RoundedRectangle

    @State private var phase: CGFloat = -0.5

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive && !reduceMotion {
                    LinearGradient(stops: [
                        .init(color: .clear,                location: 0.30),
                        .init(color: .white.opacity(0.42), location: 0.50),
                        .init(color: .clear,                location: 0.70),
                    ],
                    startPoint: UnitPoint(x: phase - 0.3, y: 0),
                    endPoint:   UnitPoint(x: phase + 0.3, y: 1))
                    .clipShape(shape)
                    .allowsHitTesting(false)
                }
            }
            // `.task(id:)`, not `.onChange(of:)`. `onChange` fires only on a
            // *change*, and the two buttons that most want a shine —
            // "Get started" and "Go to my watchlist" — are enabled from
            // their first frame, so the sweep never started on either of
            // them. `.task(id:)` runs on appear as well as on change.
            .task(id: isActive) {
                guard isActive, !reduceMotion else { return }
                phase = -0.5
                withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) {
                    phase = 2.1
                }
            }
    }
}

extension View {
    func shine(isActive: Bool, reduceMotion: Bool, shape: RoundedRectangle) -> some View {
        modifier(Shine(isActive: isActive, reduceMotion: reduceMotion, shape: shape))
    }
}

// MARK: - Deal-in

/// The finish screen's covers, arriving like cards being dealt.
///
/// Each lands from slightly off to the side with a small rotation that
/// settles to nothing — the same gesture as a hand of cards hitting a
/// table, which is the right register for "here is what you just picked".
struct DealtCard: ViewModifier {

    let index: Int
    let isDealt: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isDealt ? 1 : 0)
            .scaleEffect(isDealt || reduceMotion ? 1 : 0.82)
            .rotationEffect(.degrees(isDealt || reduceMotion ? 0 : Double(index - 1) * 9))
            .offset(y: isDealt || reduceMotion ? 0 : 34)
            .animation(reduceMotion
                       ? .easeOut(duration: AppMotion.standard)
                       : .spring(response: 0.55, dampingFraction: 0.7)
                           .delay(Double(index) * 0.09),
                       value: isDealt)
    }
}

extension View {
    func dealtCard(index: Int, isDealt: Bool, reduceMotion: Bool) -> some View {
        modifier(DealtCard(index: index, isDealt: isDealt, reduceMotion: reduceMotion))
    }
}

// MARK: - Payoff burst

/// Three rings expanding out of the finish screen's seal and fading.
///
/// Strictly decoration, and the only thing in the flow that is. It fires
/// once, on the screen whose entire job is to feel like an arrival.
struct PayoffBurst: View {

    let isOn: Bool
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            ForEach(0 ..< 3, id: \.self) { index in
                Circle()
                    .strokeBorder(Color.accentColor.opacity(0.55), lineWidth: 1.5)
                    .scaleEffect(isOn ? 2.6 : 0.45)
                    .opacity(isOn ? 0 : 0.9)
                    .animation(reduceMotion
                               ? nil
                               : .easeOut(duration: 1.7).delay(Double(index) * 0.26),
                               value: isOn)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
