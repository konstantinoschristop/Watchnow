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
    let isInWatchedList: Bool
    let hasTrailer: Bool

    let onWatchlistTap: () -> Void
    let onWatchedTap: () -> Void
    let onTrailerTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ActionPill(
                icon:    isInWatchList ? "bookmark.fill" : "bookmark",
                label:   isInWatchList ? "Saved" : "Save",
                style:   isInWatchList ? .activeAccent : .neutral,
                action:  onWatchlistTap
            )

            ActionPill(
                icon:    isInWatchedList ? "eye.fill" : "eye",
                label:   "Watched",
                style:   isInWatchedList ? .activeGreen : .neutral,
                action:  onWatchedTap
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
        .padding(.horizontal, 16)
    }
}

// MARK: - ActionPill

private struct ActionPill: View {

    enum Style {
        case neutral       // material + primary label
        case activeAccent  // accent fill + white label
        case activeGreen   // green fill + white label
    }

    let icon:   String
    let label:  String
    let style:  Style
    let action: () -> Void

    private let height: CGFloat = 52
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
            .background {
                ZStack {
                    // Material base — readable over any poster colour.
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    // Coloured fill, only painted when the pill is active.
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
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: style != .neutral)
    }

    private var foreground: Color {
        switch style {
        case .neutral:       return .primary
        case .activeAccent,
             .activeGreen:   return .white
        }
    }

    private var fill: Color? {
        switch style {
        case .neutral:       return nil
        case .activeAccent:  return .accentColor
        case .activeGreen:   return .green
        }
    }

    private var borderColor: Color {
        switch style {
        case .neutral:       return .primary.opacity(0.12)
        case .activeAccent:  return .accentColor.opacity(0.35)
        case .activeGreen:   return .green.opacity(0.35)
        }
    }
}
