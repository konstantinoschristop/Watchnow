//
//  SearchHeroMarquee.swift
//  Watchnow
//
//  Created by k.christopoulos on 31/8/26.
//
//  The drifting poster band behind the search screen's headline, split out
//  of `SearchStartView` — the marquee is a self-contained piece of motion
//  with its own timing model and nothing to say about search itself.
//

import SwiftUI

// MARK: - BlinkingCaret

/// Text cursor for the typed hint.
///
/// Its own view with its own `@State` on purpose: the parent re-renders on
/// every keystroke of the typewriter, and an animation started in the
/// parent would be torn down and restarted forty times a second. Nothing
/// here depends on the typed text, so SwiftUI leaves the blink alone.
struct BlinkingCaret: View {
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
struct HeroMarquee: View {
    let rowOne: [URL]
    let rowTwo: [URL]
    let rowThree: [URL]
    let reduceMotion: Bool

    private let tilt: Double = -11
    private let overscale: CGFloat = 1.45

    /// Three rows, not two, so the stack is taller than the band that
    /// crops it.
    ///
    /// Two rows came to roughly the band's own height, which put the top
    /// row's upper edge inside the visible area — a straight line running
    /// across the artwork where the posters simply began. The band is meant
    /// to read as a window onto a larger field of art, and a window shows
    /// no edges. A third row pushes the outer edges ~90pt beyond the crop
    /// on both sides, so only poster *bodies* are ever in frame.
    ///
    /// Speeds are deliberately non-multiples of each other: rows on
    /// harmonically related speeds drift back into alignment every so
    /// often and momentarily read as one sliding sheet.
    var body: some View {
        VStack(spacing: 8) {
            DriftRow(posters: rowOne,   reversed: false, speed: 13, reduceMotion: reduceMotion)
            DriftRow(posters: rowTwo,   reversed: true,  speed: 10, reduceMotion: reduceMotion)
            DriftRow(posters: rowThree, reversed: false, speed: 16, reduceMotion: reduceMotion)
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
/// The position is a pure function of wall-clock time, not the output of an
/// animation. That distinction is the whole design: an animation belongs to
/// a view, so it restarted from the beginning every time the tab was
/// re-entered, which read as the marquee reloading from scratch. Deriving
/// the offset from a fixed epoch means the strip is always exactly where it
/// would have been had it never stopped — leaving the tab and coming back
/// resumes mid-glide.
///
/// `TimelineView` re-runs only its own closure per frame, not this view's
/// `body`, so the strip's child views are built once and each frame merely
/// re-applies an offset to them. The `KFImage`s never see a changed input
/// and so never re-fetch.
private struct DriftRow: View {
    let posters: [URL]
    /// `true` sends this row right instead of left.
    let reversed: Bool
    /// Points per second. Slow enough to read as ambience rather than as a
    /// carousel the user is expected to track.
    let speed: CGFloat
    let reduceMotion: Bool

    /// Shared, fixed origin for every row's phase. Static so it outlives
    /// any individual row and survives the tab being torn down and rebuilt.
    private static let epoch = Date()

    private let posterWidth: CGFloat = 80
    private let posterHeight: CGFloat = 120
    private let spacing: CGFloat = 8

    /// The source list repeated until one copy is wider than any phone.
    ///
    /// The strip is drawn as two copies back to back and travels exactly
    /// one copy's width, so coverage is only guaranteed while a single copy
    /// is at least as wide as the viewport. With a short feed — a handful
    /// of trending series, or a day where most lack poster art — one copy
    /// came out narrower than the screen and the drift exposed a bare gap
    /// partway through every cycle.
    private var tiled: [URL] {
        guard !posters.isEmpty else { return [] }
        // Six slots is ~528pt per copy, comfortably past the 402pt the
        // enclosing ScrollView is offered. Kept as low as coverage allows
        // because this count is now paid three times over.
        let minimumSlots = 6
        guard posters.count < minimumSlots else { return posters }
        return (0..<minimumSlots).map { posters[$0 % posters.count] }
    }

    /// Width of one full copy — the exact distance to travel before the
    /// duplicate lines up with the original.
    private var loopWidth: CGFloat {
        CGFloat(tiled.count) * (posterWidth + spacing)
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
        if tiled.isEmpty {
            placeholder
        } else {
            // Built once per body evaluation and captured, so the per-frame
            // closure below only re-wraps an existing view value.
            let strip = stripView

            TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                    paused: reduceMotion)) { context in
                strip.offset(x: -phase(at: context.date))
            }
        }
    }

    private var stripView: some View {
        HStack(spacing: spacing) {
            // Two copies back to back. `id` includes the copy index so
            // SwiftUI doesn't reuse one view for both halves.
            ForEach(0..<(tiled.count * 2), id: \.self) { index in
                PosterImage(url: tiled[index % tiled.count],
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
                    // Hairline edge so neighbouring posters stay distinct
                    // where two dark ones meet.
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
                    }
            }
        }
    }

    /// How far the strip has travelled, wrapped into a single copy's width.
    ///
    /// Kept inside `0…loopWidth` on purpose: at any value in that range one
    /// of the two copies covers the viewport, so there is no phase at which
    /// the row can show empty background.
    private func phase(at date: Date) -> CGFloat {
        guard loopWidth > 0 else { return 0 }
        guard !reduceMotion else { return reversed ? loopWidth : 0 }

        let travelled = CGFloat(date.timeIntervalSince(Self.epoch)) * speed
        let wrapped = travelled.truncatingRemainder(dividingBy: loopWidth)
        return reversed ? loopWidth - wrapped : wrapped
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
}
