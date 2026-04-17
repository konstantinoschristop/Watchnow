//
//  PrimaryActionRow.swift
//  Watchnow
//
//  The primary action row shown directly under the hero on the details screen:
//  Watchlist toggle and Trailer (when available). Share lives in the nav bar
//  so it stays reachable after scrolling past the hero.
//

import SwiftUI

struct PrimaryActionRow: View {

    let isInWatchList: Bool
    let hasTrailer: Bool

    let onWatchlistTap: () -> Void
    let onTrailerTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ActionButton(
                systemImage: isInWatchList ? "checkmark" : "plus",
                title: isInWatchList ? "In Watchlist" : "Watchlist",
                accent: isInWatchList ? .green : .accentColor,
                action: onWatchlistTap
            )

            if hasTrailer {
                ActionButton(
                    systemImage: "play.fill",
                    title: "Trailer",
                    accent: .red,
                    action: onTrailerTap
                )
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Button pieces

private struct ActionButton: View {
    let systemImage: String
    let title: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ActionButtonLabel(systemImage: systemImage, title: title, accent: accent)
        }
        .buttonStyle(.plain)
    }
}

private struct ActionButtonLabel: View {
    let systemImage: String
    let title: String
    let accent: Color

    /// Shape reused for both fill and stroke so the tinted background and
    /// border always trace the exact same rounded rectangle.
    private let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
            Text(title)
                .font(.system(size: 15, weight: .bold))
        }
        .foregroundStyle(accent)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        // Layered background: a faint material floor gives the button some
        // depth on top of the hero fader, and the tinted fill on top of it
        // carries the accent strongly enough that the control reads as a
        // real button — not just tinted text on glass — without flipping
        // to a fully saturated CTA (that role belongs to the sticky
        // "Watch Now" strip at the bottom of the screen).
        .background {
            shape.fill(.ultraThinMaterial)
        }
        .background {
            shape.fill(accent.opacity(0.18))
        }
        .overlay {
            shape.strokeBorder(accent.opacity(0.45), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
    }
}
