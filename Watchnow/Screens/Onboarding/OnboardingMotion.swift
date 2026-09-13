//
//  OnboardingMotion.swift
//  Watchnow
//
//  The motion vocabulary for the first run.
//
//  Onboarding is the one screen every new user sees and most of them see
//  only once, so it is worth moving. The rule throughout is that motion
//  should explain something: the grid cascades so the eye is led through it
//  rather than dumped in front of it, steps slide in the direction of
//  travel so "back" and "forward" have a shape, and the finish screen deals
//  the saved covers like cards because that is the payoff the whole flow
//  was building to.
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
struct StaggeredReveal: ViewModifier {

    let index: Int
    let isRevealed: Bool
    let reduceMotion: Bool

    private static let step: Double = 0.028
    private static let maximumDelay: Double = 0.36

    private var delay: Double { min(Double(index) * Self.step, Self.maximumDelay) }

    func body(content: Content) -> some View {
        content
            .opacity(isRevealed ? 1 : 0)
            .scaleEffect(isRevealed || reduceMotion ? 1 : 0.9)
            .offset(y: isRevealed || reduceMotion ? 0 : 14)
            .animation(reduceMotion
                       ? .easeOut(duration: AppMotion.standard)
                       : .spring(response: 0.5, dampingFraction: 0.78).delay(delay),
                       value: isRevealed)
    }
}

extension View {
    func staggeredReveal(index: Int, isRevealed: Bool, reduceMotion: Bool) -> some View {
        modifier(StaggeredReveal(index: index, isRevealed: isRevealed, reduceMotion: reduceMotion))
    }
}

// MARK: - Step transition

extension AnyTransition {

    /// A plain cross-fade, deliberately.
    ///
    /// A directional slide was tried first and looked wrong for a reason
    /// worth recording: the step's content is a thirty-item `LazyVGrid`
    /// whose cells are already animating their own reveal, so sliding the
    /// container at the same time left posters scattered across the screen
    /// mid-flight with their captions detached. The cascade below is what
    /// carries the sense of arrival; the container only needs to get out of
    /// its way.
    static var onboardingStep: AnyTransition { .opacity }
}

// MARK: - Ambient backdrop

/// Two very soft colour fields drifting behind the content.
///
/// Nothing here is legible as a shape — at this blur radius it reads as the
/// background being faintly alive rather than as decoration, which is the
/// difference between a screen that feels finished and one that feels
/// static. Tinted with the app's accent and the icon's gold so the first
/// screen quietly carries the brand.
struct AmbientBackdrop: View {

    let reduceMotion: Bool
    @State private var drifted = false

    var body: some View {
        ZStack {
            blob(Color.accentColor.opacity(0.11), diameter: 340)
                .offset(x: drifted ? -80 : 70, y: drifted ? -280 : -220)

            // Gold carries far more than blue at the same opacity — at the
            // value the accent uses it read as a stain in the empty lower
            // half rather than as light.
            blob(WatchnowBrand.gold.opacity(0.06), diameter: 300)
                .offset(x: drifted ? 100 : -60, y: drifted ? 260 : 330)
        }
        .blur(radius: 90)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                drifted = true
            }
        }
    }

    private func blob(_ color: Color, diameter: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: diameter, height: diameter)
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
