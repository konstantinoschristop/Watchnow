//
//  PrimaryActionRow.swift
//  Watchnow
//
//  The actions under the hero, on one row:
//
//      [ Watch Later ]  (♥)  (✓)  [ ▶ Trailer ]
//
//  While the trailer plays in the hero, Trailer turns into Close.
//
//  Save and Trailer keep their words because they are the two actions a
//  first-time visitor is looking for. Like and Watched are icon-only
//  circles: a heart and a tick are read faster than "I like this series"
//  and "Mark as watched", and spelling them out was costing the screen two
//  extra full-width rows before anything about the title itself.
//
//  It degrades in two steps rather than truncating:
//   - If the labels don't fit on one line (long translations, larger text),
//     Trailer drops its word and becomes a circle too.
//   - At accessibility sizes every action gets its own labelled full-width
//     row — the earlier layout, which is the right one when the words need
//     the room.
//
//  Styling: one glass family. The neutral state is plain glass with a
//  `.primary` label; Saved is the only thing that fills with the accent,
//  because it is the state the user most needs to see at a glance. Liked and
//  Watched carry their state in the glyph (filled heart, filled tick) so the
//  row never turns into three competing blue blocks.
//

import SwiftUI

struct PrimaryActionRow: View {

    let isInWatchList: Bool
    let hasTrailer: Bool
    /// Only used to word the taste button.
    let isSeries: Bool
    let isLiked: Bool
    let isWatched: Bool
    /// The trailer is playing in the hero: the Trailer action closes it.
    var isTrailerPlaying: Bool = false

    let onWatchlistTap: () -> Void
    let onTrailerTap: () -> Void
    let onLikeTap: () -> Void
    let onWatchedTap: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                stacked
            } else {
                ViewThatFits(in: .horizontal) {
                    row(trailerHasLabel: true)
                    row(trailerHasLabel: false)
                    stacked
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Layouts

    private func row(trailerHasLabel: Bool) -> some View {
        GlassGroup(spacing: 8) {
            HStack(spacing: 8) {
                watchlistButton()
                likeButton(showsLabel: false)
                watchedButton(showsLabel: false)
                if hasTrailer || isTrailerPlaying {
                    // Natural width, so Save is the one that stretches: two
                    // flexible pills split the row evenly and the longer
                    // label truncates even when both would have fit.
                    trailerButton(showsLabel: trailerHasLabel, fills: false)
                }
            }
        }
    }

    private var stacked: some View {
        GlassGroup(spacing: 10) {
            VStack(spacing: 10) {
                watchlistButton()
                if hasTrailer || isTrailerPlaying { trailerButton(showsLabel: true, fills: true) }
                likeButton(showsLabel: true)
                watchedButton(showsLabel: true)
            }
        }
    }

    // MARK: - Buttons

    private func watchlistButton() -> some View {
        ActionButton(
            icon: isInWatchList ? "bookmark.fill" : "bookmark",
            label: isInWatchList
                ? String(localized: "Saved", comment: "Button state: the title is in the watchlist")
                : String(localized: "Watch Later", comment: "Button: add the title to the watchlist"),
            isOn: isInWatchList,
            style: isInWatchList ? .prominent : .neutral,
            action: onWatchlistTap
        )
    }

    private func trailerButton(showsLabel: Bool, fills: Bool) -> some View {
        ActionButton(
            icon: isTrailerPlaying ? "xmark" : "play.fill",
            label: showsLabel ? trailerLabel : nil,
            fills: fills,
            isOn: false,
            style: .neutral,
            action: onTrailerTap
        )
        .accessibilityLabel(isTrailerPlaying
                            ? String(localized: "Close trailer", comment: "Accessibility: closes the trailer playing at the top of the page")
                            : String(localized: "Trailer", comment: "Button: play the trailer"))
    }

    private var trailerLabel: String {
        isTrailerPlaying
            ? String(localized: "Close", comment: "Button: close the trailer playing at the top of the page")
            : String(localized: "Trailer", comment: "Button: play the trailer")
    }

    private func likeButton(showsLabel: Bool) -> some View {
        ActionButton(
            icon: isLiked ? "heart.fill" : "heart",
            label: showsLabel
                ? (isLiked ? String(localized: "Liked", comment: "Button state: the user liked this title") : likeLabel)
                : nil,
            iconTint: isLiked ? .red : nil,
            burst: .hearts(.red),
            isOn: isLiked,
            style: .neutral,
            action: onLikeTap
        )
        .accessibilityLabel(isLiked
                            ? String(localized: "Liked. Tap to remove from your taste profile.")
                            : likeLabel)
    }

    private func watchedButton(showsLabel: Bool) -> some View {
        ActionButton(
            icon: isWatched ? "checkmark.circle.fill" : "checkmark.circle",
            label: showsLabel
                ? (isWatched
                   ? String(localized: "Watched", comment: "Button state: the user has watched this title")
                   : String(localized: "Mark as watched"))
                : nil,
            iconTint: isWatched ? .accentColor : nil,
            burst: .ring(.accentColor),
            isOn: isWatched,
            style: .neutral,
            action: onWatchedTap
        )
        .accessibilityLabel(isWatched
                            ? String(localized: "Watched. Tap to unmark.")
                            : String(localized: "Mark as watched"))
    }

    private var likeLabel: String {
        isSeries
            ? String(localized: "I like this series", comment: "Button: add this series to the user's taste profile")
            : String(localized: "I like this movie", comment: "Button: add this movie to the user's taste profile")
    }
}

// MARK: - ActionButton

/// One action. With a label it is a flexible pill; without one it is a
/// fixed circle the same height, so the row keeps a single baseline.
private struct ActionButton: View {

    enum Style {
        case neutral    // plain glass, primary label
        case prominent  // accent-tinted glass, white label
    }

    let icon: String
    let label: String?
    /// Labelled pills only: take all the width on offer, or keep to the
    /// label's own width.
    var fills: Bool = true
    /// Colours the glyph only, on neutral glass — how Liked and Watched
    /// show their state without filling the whole control.
    var iconTint: Color? = nil
    /// Played around the control when it turns on.
    var burst: ToggleBurst.Kind? = nil
    let isOn: Bool
    let style: Style
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 50

    var body: some View {
        Button(action: action) {
            content
                .foregroundStyle(foreground)
                .frame(height: height)
                .frame(width: label == nil ? height : nil)
                .frame(maxWidth: label != nil && fills ? .infinity : nil)
                .fixedSize(horizontal: label != nil && !fills, vertical: false)
                .contentShape(shape)
                .modifier(ActionButtonBackground(style: style, shape: shape))
        }
        .buttonStyle(PressableStyle())
        .overlay {
            if let burst {
                ToggleBurst(kind: burst, isOn: isOn)
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isOn)
    }

    @ViewBuilder
    private var content: some View {
        let glyph = Image(systemName: icon)
            .appFont(label == nil ? 18 : 16, weight: .semibold, relativeTo: .body)
            .foregroundStyle(iconTint.map { AnyShapeStyle($0) } ?? AnyShapeStyle(foreground))
            .symbolEffect(.bounce.up.byLayer, value: isOn)
            .contentTransition(.symbolEffect(.replace.downUp))

        if let label {
            HStack(spacing: 6) {
                glyph
                Text(label)
                    .appFont(15, weight: .semibold, relativeTo: .subheadline)
                    .lineLimit(1)
                    // "Watch Later" → "Saved" morphs rather than blinks.
                    .contentTransition(.interpolate)
            }
            .padding(.horizontal, 14)
            .animation(.snappy, value: label)
        } else {
            glyph
        }
    }

    private var shape: some Shape {
        RoundedRectangle(cornerRadius: label == nil ? height / 2 : AppRadius.surface,
                         style: .continuous)
    }

    private var foreground: Color {
        switch style {
        case .neutral:   return .primary
        case .prominent: return .white
        }
    }
}

// MARK: - Background

/// Liquid glass on iOS 26, `.ultraThinMaterial` with a hairline below it.
private struct ActionButtonBackground<S: Shape>: ViewModifier {

    let style: ActionButton.Style
    let shape: S

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(glass, in: shape)
        } else {
            content
                .background {
                    ZStack {
                        shape.fill(.ultraThinMaterial)
                        if style == .prominent {
                            shape.fill(Color.accentColor)
                        }
                    }
                }
                .overlay {
                    shape.stroke(style == .prominent
                                 ? Color.accentColor.opacity(0.35)
                                 : Color.primary.opacity(0.10),
                                 lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
        }
    }

    @available(iOS 26.0, *)
    private var glass: Glass {
        switch style {
        case .neutral:   return .regular.interactive()
        case .prominent: return .regular.tint(.accentColor).interactive()
        }
    }
}

// MARK: - GlassGroup

/// `GlassEffectContainer` where it exists, so neighbouring glass shapes
/// share one sampling pass and blend at their edges; a passthrough below.
struct GlassGroup<Content: View>: View {

    var spacing: CGFloat? = nil
    @ViewBuilder let content: Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

// MARK: - Press

/// A squeeze on touch-down, released with a little spring. iOS 26's
/// interactive glass already reacts to touch; this gives the fallback
/// surfaces the same physical feel, and it is subtle enough to stack.
private struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
