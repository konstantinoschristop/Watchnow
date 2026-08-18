//
//  PrimaryActionRow.swift
//  Watchnow
//
//  Three equal-width action pills under the hero. Designed for clarity
//  over flair: every button reads as "tappable" via the same neutral
//  material base, and the toggled-on states (Saved / Watched) lift
//  themselves visually with a strong tinted fill + white label.
//
//  Accessibility wins from the new colour scheme:
//   - Inactive labels are `.primary` on `.ultraThinMaterial` — full
//     system contrast in both light and dark mode (was tinted text on
//     low-opacity tint, which failed AA at small sizes).
//   - Active labels are `.white` on a saturated accent fill — also AA+.
//   - Trailer is a neutral one-shot action; no faux active state, so
//     the user is never confused about whether tapping it "did" something.
//

import SwiftUI

struct PrimaryActionRow: View {

    let isInWatchList: Bool
    let hasTrailer: Bool
    /// "movie" or "series" — only used to word the taste button.
    let mediaKind: String
    let isLiked: Bool

    let onWatchlistTap: () -> Void
    let onTrailerTap: () -> Void
    let onLikeTap: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ActionPill(
                    icon:    isInWatchList ? "bookmark.fill" : "bookmark",
                    label:   isInWatchList ? "Saved" : "Watch Later",
                    style:   isInWatchList ? .activeAccent : .neutral,
                    action:  onWatchlistTap
                )

                if hasTrailer {
                    ActionPill(
                        icon:   "play.fill",
                        label:  "Trailer",
                        style:  .neutral,
                        action: onTrailerTap
                    )
                }
            }

            // Taste signal. Given its own full-width row rather than a third
            // pill: "I like this movie" doesn't fit in a third of the width,
            // and squeezing it would also crush "Watch Later". Shorter and
            // lighter than the row above so it reads as secondary.
            ActionPill(
                icon:   isLiked ? "heart.fill" : "heart",
                label:  isLiked ? "Liked" : "I like this \(mediaKind)",
                style:  isLiked ? .activeAccent : .neutral,
                height: 44,
                action: onLikeTap
            )
            .accessibilityLabel(isLiked
                                ? "Liked. Tap to remove from your taste profile."
                                : "I like this \(mediaKind)")
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - ActionPill

private struct ActionPill: View {

    enum Style {
        case neutral       // material + primary label
        case activeAccent  // accent fill + white label
    }

    let icon:   String
    let label:  String
    let style:  Style
    var height: CGFloat = 52
    let action: () -> Void

    private let radius: CGFloat = 14

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .symbolEffect(.bounce, value: style != .neutral)
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .modifier(ActionPillBackground(style: style, radius: radius))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: style != .neutral)
    }

    private var foreground: Color {
        switch style {
        case .neutral:       return .primary
        case .activeAccent:  return .white
        }
    }
}

// MARK: - ActionPillBackground

/// Applies the pill surface on iOS 26+ with liquid-glass and on earlier
/// OS with the classic material + coloured fill combo.
///
/// iOS 26 strategy:
///  • Neutral  → plain glass (`GlassEffect.regular`) — frosted, no tint.
///  • Active   → tinted glass (`GlassEffect.regular.tinted()`) tinted with
///    the accent colour.
///
/// Pre-iOS 26 strategy (unchanged):
///  • `.ultraThinMaterial` base + optional solid colour overlay + stroke.
private struct ActionPillBackground: ViewModifier {

    let style: ActionPill.Style
    let radius: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(style == .neutral ? .regular : .regular.tint(glassTint),
                             in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .tint(glassTint)
        } else {
            content
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(.ultraThinMaterial)
                        if let fill {
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .fill(fill)
                        }
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.10), radius: 3, y: 2)
        }
    }

    private var glassTint: Color {
        switch style {
        case .neutral:       return .accentColor   // irrelevant — .regular has no tint
        case .activeAccent:  return .accentColor
        }
    }

    private var fill: Color? {
        switch style {
        case .neutral:       return nil
        case .activeAccent:  return .accentColor
        }
    }

    private var borderColor: Color {
        switch style {
        case .neutral:       return .primary.opacity(0.12)
        case .activeAccent:  return .accentColor.opacity(0.35)
        }
    }
}
