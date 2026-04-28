//
//  HeroOverlayView.swift
//  Watchnow
//
//  Overlay content for the hero (MenuFeaturedView) on the details screen.
//  Renders title + inline meta (rating • year • runtime/seasons) + genre pills
//  over the backdrop's bottom gradient.
//

import SwiftUI

struct HeroOverlayView: View {

    let title: String
    let rating: Double?
    let year: String?
    let runtimeOrSeasons: String?
    let genres: [Genres]

    /// Height of the bottom-edge fader that dissolves the hero into the
    /// scroll background below. Generous on purpose — a short fader
    /// packs the whole ramp into a visible band and reads as a crisp
    /// line; spreading the ramp over ~90pt with eased intermediate
    /// stops makes the transition feel like a gradient of light rather
    /// than an overlay edge.
    private let bottomFadeHeight: CGFloat = 70

    var body: some View {
        ZStack(alignment: .bottom) {
            // Top scrim — covers the status-bar / Dynamic Island safe area
            // so the image bleed looks intentional rather than clipped.
            // Three stops give a soft vignette: darkest at the very top
            // (where system UI lives), easing to transparent by ~120 pt.
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.6),  location: 0.0),
                    .init(color: .black.opacity(0.2),  location: 0.5),
                    .init(color: .clear,               location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)

            // Main scrim — darkens the backdrop underneath for text
            // legibility. Bottom stop stays modest (0.5 opacity) because
            // the fader below handles the real darkening into the app
            // background; stacking a very dark scrim under the fader
            // produces a muddy mid-band rather than a clean blend.
            LinearGradient(
                stops: [
                    .init(color: .clear,                  location: 0.0),
                    .init(color: .black.opacity(0.45),    location: 0.55),
                    .init(color: .black.opacity(0.5),     location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Bottom fader — dissolves the hero into the exact app
            // background colour so the scroll content below grows out of
            // the image rather than starting after a tone cut. Four stops
            // give the ramp an eased S-curve: barely touched at the top,
            // accelerates through the middle, arrives solid at the bottom.
            // Without the intermediate stops the same gradient reads as
            // a straight line — which was the "aggressive" feel before.
            LinearGradient(
                stops: [
                    .init(color: .clear,                               location: 0.0),
                    .init(color: Color(.background).opacity(0.18),     location: 0.35),
                    .init(color: Color(.background).opacity(0.6),      location: 0.72),
                    .init(color: Color(.background),                   location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: bottomFadeHeight)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.custom("AvenirNext-Bold", size: 26))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .shadow(color: .black.opacity(0.6), radius: 3)

                metaRow

                if !genres.isEmpty { genrePills }
            }
            .padding(.horizontal)
            // Text sits ~20% down into the fader, where the background
            // wash is still barely present (~10% opacity) and the main
            // scrim is ~48% black — plenty of contrast for white type
            // with a shadow. Going deeper into the fader starts washing
            // the type out; going above it sacrifices the low, cinematic
            // feel that made the hero work in the first place.
            .padding(.bottom, bottomFadeHeight * 0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Meta row (⭐ rating • year • runtime/seasons)
    @ViewBuilder
    private var metaRow: some View {
        let parts: [MetaPart] = buildMetaParts()

        if !parts.isEmpty {
            HStack(spacing: 6) {
                ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                    if index > 0 {
                        Text("•")
                            .foregroundColor(.white.opacity(0.7))
                    }
                    part.view
                }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white.opacity(0.9))
            .shadow(color: .black.opacity(0.5), radius: 2)
        }
    }

    private struct MetaPart {
        let view: AnyView
    }

    private func buildMetaParts() -> [MetaPart] {
        var parts: [MetaPart] = []

        if let rating, rating > 0 {
            parts.append(MetaPart(view: AnyView(
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .foregroundColor(RatingStyle.tint(for: rating))
                    Text(String(format: "%.1f", rating))
                }
            )))
        }
        if let year, !year.isEmpty {
            parts.append(MetaPart(view: AnyView(Text(year))))
        }
        if let runtimeOrSeasons, !runtimeOrSeasons.isEmpty {
            parts.append(MetaPart(view: AnyView(Text(runtimeOrSeasons))))
        }
        return parts
    }

    // MARK: - Genre pills
    private var genrePills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(genres, id: \.self) { genre in
                    Text(genre.name ?? "- -")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial.opacity(0.9), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))
                }
            }
        }
    }
}
