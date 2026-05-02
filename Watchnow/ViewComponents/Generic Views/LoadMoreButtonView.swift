//
//  LoadMoreButtonView.swift
//  Watchnow
//
//  Trailing-edge button for the horizontal carousels. Shown by
//  `StretchingActionScrollView` and grows with the user's overscroll
//  progress (0 → 1) — at threshold the parent fires the load-more
//  action and the carousel snaps back. The growth animation gives the
//  user immediate, in-thumb feedback that they're going to trigger
//  something, without a separate spinner or modal.
//
//  Why an `ObservableObject` instead of a plain `progress` prop:
//  `StretchingActionScrollView` is a UIViewRepresentable that buffers
//  parent updates while the user is dragging (to avoid mid-scroll
//  layout jumps that destabilize UIScrollView). With a plain `let
//  progress` prop, the button's parent re-renders during the pull but
//  the rootView replacement is buffered, so the button stays frozen
//  at progress=0 until release. An `ObservableObject` reaches inside
//  the buffered tree — SwiftUI re-renders the leaf view as soon as
//  `@Published progress` changes, regardless of rootView buffering.
//
//  Visual:
//   - At rest (progress 0): translucent material circle with a small
//     accent-tinted chevron. Reads as "there's more available, keep
//     scrolling".
//   - As progress climbs: the circle grows (eased), fills with accent
//     colour, the chevron flips to white, and an accent glow appears.
//     Reads as "release to load".
//

import SwiftUI

@MainActor
final class LoadMoreProgress: ObservableObject {
    @Published var value: CGFloat = 0
}

struct LoadMoreButtonView: View {

    /// Driven by the parent section's `StretchingActionScrollView`
    /// `onProgress` callback. See file header for why this is an
    /// `ObservableObject` rather than a plain prop.
    @ObservedObject var tracker: LoadMoreProgress

    private let baseSize:   CGFloat = 40
    private let maxGrowth:  CGFloat = 40   // 40 → 80 — bigger payoff at threshold

    /// The button's outer container stays this wide so the scrollview's
    /// `contentSize` doesn't change as the inner circle grows. UIScrollView
    /// clamps overscroll when contentSize shifts mid-gesture, which was
    /// stopping the user from pulling far enough to trigger load-more.
    private var maxSize: CGFloat { baseSize + maxGrowth }

    private var p: CGFloat { min(max(tracker.value, 0), 1) }

    /// Eased progress — `pow(p, 1.6)` keeps growth slow at the start and
    /// accelerates dramatically as the user pulls past ~60% of the
    /// threshold. The button feels like it's "waking up" the closer
    /// release gets to triggering, which makes the moment of arming
    /// physically obvious without having to look at the chevron flip.
    private var easedP: CGFloat { pow(p, 1.6) }

    private var size: CGFloat { baseSize + (easedP * maxGrowth) }

    /// Past this point the button reads as "armed" and visually flips
    /// — accent fill, white chevron — instead of "approaching".
    private var isArmed: Bool { p > 0.65 }

    var body: some View {
        ZStack {
            // Translucent base so the row's content / background reads
            // through. Stays the same across all progress values.
            Circle()
                .fill(.ultraThinMaterial)

            // Accent fill ramps in with progress. By threshold it's
            // fully opaque — reads as a primary CTA at the moment of
            // release.
            Circle()
                .fill(Color.accentColor.opacity(p))

            // Border tints with progress: subtle at rest, prominent
            // at threshold.
            Circle()
                .strokeBorder(
                    Color.accentColor.opacity(0.30 + p * 0.45),
                    lineWidth: 1.5
                )

            Image(systemName: "arrow.right")
                .font(.system(size: 14 + easedP * 12, weight: .bold))
                .foregroundStyle(isArmed ? Color.white : Color.accentColor)
                .animation(.easeInOut(duration: 0.15), value: isArmed)
        }
        .frame(width: size, height: size)
        // Soft accent glow that intensifies with progress — stays out of
        // the way at rest, becomes a clear "ready" signal near threshold.
        .shadow(color: Color.accentColor.opacity(p * 0.4), radius: 6, y: 0)
        // Outer container is pinned at `maxSize` so the carousel's
        // contentSize stays constant whether the inner circle is at 40pt
        // or 80pt. Without this, the growing button kept resizing the
        // scrollview's content mid-gesture, which made UIScrollView clamp
        // the overscroll back to the edge — visually "stuck", couldn't
        // pull far enough to fire onTriggered.
        .frame(width: maxSize, height: maxSize)
        .frame(maxHeight: .infinity)
        .padding(.leading, 24)
        .padding(.trailing, 16)
    }
}
