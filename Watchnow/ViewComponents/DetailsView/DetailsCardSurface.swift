//
//  DetailsCardSurface.swift
//  Watchnow
//
//  The one card surface the details screen's grouped sections sit on — the
//  provider strip, the ratings card, the Coach card's body.
//
//  `tertiarySystemBackground` rather than `secondarySystemBackground`: the
//  screen itself is `systemGray6`, which is the same colour as
//  `secondarySystemBackground` in light mode, so cards drawn with it only
//  existed because of their shadow. Tertiary resolves to white on the light
//  page and to a step lighter than the page in dark, which is the lift the
//  cards were meant to have all along.
//

import SwiftUI

struct DetailsCardSurface: ViewModifier {

    var radius: CGFloat = AppRadius.surface

    func body(content: Content) -> some View {
        content
            .background {
                // The shadow on the card's shape alone. On the whole card it
                // was worked out from everything inside it, again whenever
                // anything inside changed — every frame of an arrival.
                AppRadius.shape(radius)
                    .fill(Color(.tertiarySystemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
            }
            .overlay {
                AppRadius.shape(radius)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
            }
    }
}

extension View {
    /// Places a details-screen section on its card. See `DetailsCardSurface`.
    func detailsCard(radius: CGFloat = AppRadius.surface) -> some View {
        modifier(DetailsCardSurface(radius: radius))
    }
}

// MARK: - Section header

/// Heading for the details screen's open sections (Cast, More like this,
/// Reviews): the same 22pt title the cards above use for theirs, with an
/// optional trailing control. Replaces the app-wide `SectionHeaderView`
/// here — its 25pt heavy title and coloured glyph were built for the home
/// feed's rows and shouted over the cards on this screen.
struct DetailsSectionHeader<Trailing: View>: View {

    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .appFont(22, weight: .bold, relativeTo: .title2)
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .appFont(14, relativeTo: .subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.horizontal, 16)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
    }
}

extension DetailsSectionHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// "See all ›" for a section header.
struct SeeAllButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Text("See all")
                Image(systemName: "chevron.right")
                    .imageScale(.small)
            }
            .appFont(15, weight: .semibold, relativeTo: .subheadline)
            .foregroundStyle(Color.accentColor)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Press

/// Cards in the carousels give under the finger and spring back.
struct CarouselPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: configuration.isPressed)
    }
}
