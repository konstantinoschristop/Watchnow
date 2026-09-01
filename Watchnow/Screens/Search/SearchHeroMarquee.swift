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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RoundedRectangle(cornerRadius: 0.5, style: .continuous)
            .frame(width: 1.5, height: 15)
            .foregroundStyle(Color.accentColor)
            .opacity(dim ? 0 : 1)
            .onAppear {
                // `HintChip` already declines to draw a caret under Reduce
                // Motion, but a view that owns a `repeatForever` should
                // refuse to start it on its own account — the guard belongs
                // where the loop is, not only where the loop is asked for.
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: AppMotion.slow).repeatForever(autoreverses: true)) {
                    dim = true
                }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - HintChip

/// The rotating search suggestion, typed out as a real control.
///
/// Owns `typedHint`/`hintTarget` and runs the typewriter itself. They used
/// to live on `SearchStartView`, which meant every character — one every
/// 42ms typing, every 20ms deleting — invalidated that view's entire body:
/// the poster band, the recents, sixteen genre chips and a twenty-card
/// trending row, rebuilt 25-50 times a second. On the main thread, against
/// a scroll gesture, that is what the screen's overscroll stutter was made
/// of. Scoped here, a keystroke re-renders a pill.
///
/// The title types itself in, holds, then backspaces away before the next
/// one starts. It stays tappable throughout and always searches
/// `hintTarget`, the *whole* title, so a tap landing mid-animation never
/// runs a half-typed query. Falls back to a plain description before
/// trending arrives, so the line is never an empty pill.
struct HintChip: View {

    /// Titles to cycle. Changing this restarts the loop.
    let titles: [String]
    let reduceMotion: Bool
    let onSelect: (String) -> Void

    /// What the hint is currently showing — a growing or shrinking prefix
    /// of `hintTarget` while the typewriter runs, or the whole title once
    /// it has finished typing.
    @State private var typedHint = ""
    /// The full title behind `typedHint`. Kept separate so a tap during the
    /// typing animation searches the whole title rather than whatever half
    /// of it happens to be on screen.
    @State private var hintTarget: String?

    var body: some View {
        content
            .frame(height: 38)
            .task(id: titles) { await runHints() }
    }

    @ViewBuilder
    private var content: some View {
        if hintTarget != nil || !typedHint.isEmpty {
            Button {
                if let hintTarget { onSelect(hintTarget) }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .appFont(12, weight: .semibold, relativeTo: .caption)

                    HStack(spacing: 1) {
                        Text(typedHint)
                            .appFont(14, weight: .semibold, relativeTo: .subheadline)
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
        } else {
            Text("Movies, series and the people who make them.")
                .appFont(14, relativeTo: .subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .transition(.opacity)
        }
    }

    // MARK: Typewriter

    /// Types each title out a character at a time, holds it, then
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
    private func runHints() async {
        while !Task.isCancelled {
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

    /// Reveals `title` one character at a time.
    private func type(_ title: String) async {
        for index in 1...max(title.count, 1) {
            guard !Task.isCancelled else { return }
            typedHint = String(title.prefix(index))
            try? await Task.sleep(for: .milliseconds(42))
        }
    }

    /// Removes `title` one character at a time. Faster than typing —
    /// deleting is the part nobody's reading, and matching the two speeds
    /// makes the whole cycle feel twice as long as it is.
    private func backspace(_ title: String) async {
        guard title.count > 0 else { return }
        for index in stride(from: title.count - 1, through: 0, by: -1) {
            guard !Task.isCancelled else { return }
            typedHint = String(title.prefix(index))
            try? await Task.sleep(for: .milliseconds(20))
        }
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
        // No blur. A 0.3pt radius was doing almost nothing visible — the
        // scrim in `hero` is what keeps the art from competing with the
        // headline — but it cost a full offscreen render pass over all
        // three rows, and because the strips move every frame that pass
        // could never be cached. Overscrolling the screen meant
        // re-rasterizing 36 over-scaled, rotated posters at 60fps while
        // UIScrollView was also driving the rubber band, which is what
        // made the pull feel like it was catching.
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
                            cornerRadius: AppRadius.small,
                            shadowRadius: 0)
                    .frame(width: posterWidth, height: posterHeight)
                    // Fill behind each poster so a slot that hasn't
                    // decoded yet reads as a card still loading rather
                    // than a hole punched in the strip.
                    .background {
                        RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                            .fill(Color(.tertiarySystemFill))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
                    // Hairline edge so neighbouring posters stay distinct
                    // where two dark ones meet.
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
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
                    ShimmerBox(cornerRadius: AppRadius.small)
                        .frame(width: posterWidth, height: posterHeight)
                }
            }
        }
    }
}
