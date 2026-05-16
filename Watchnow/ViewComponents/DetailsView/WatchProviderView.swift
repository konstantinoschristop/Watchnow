//
//  WatchProviderView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 1/8/23.
//
//  The "Available on" section — the single biggest reason people keep this
//  app installed, so it's treated as a first-class, tinted card rather
//  than a plain scrolling strip.
//
//  Layout:
//    - Green-tinted rounded card (mirrors the section header's green icon)
//    - "STREAM" subgroup (green dot) — subscription services, the
//      primary reason users open the app
//    - "RENT" subgroup (amber dot) — pay-per-title rentals
//    - "BUY" subgroup (blue dot) — own-it-outright purchases; shown
//      separately from rent because the two often overlap (same
//      storefront offers both) but the user intent is different
//    - JustWatch attribution line pinned to the bottom of the card
//
//  Logos are intentionally larger (62pt) and rounded-square (14pt radius)
//  instead of the old 50pt circles. Streaming brand marks are designed
//  for square canvases, and the larger tile size makes the logos
//  recognizable at a glance — which is the whole point of the section.
//

import SwiftUI

struct WatchProviderView: View {

    let flatrates: [Flatrate]
    let rent: [Flatrate]
    let buy: [Flatrate]
    /// JustWatch deeplink for the title in the user's region. When present,
    /// the card's attribution line becomes a tappable "Open on JustWatch"
    /// action — which replaces the old sticky bottom CTA. Nil when the
    /// region has no deeplink available.
    let justWatchURL: URL?

    @State private var isJustWatchPresented = false

    private let cardCornerRadius: CGFloat = 18
    private let tileSize: CGFloat = 62
    private let tileCornerRadius: CGFloat = 14
    private let tileLabelWidth: CGFloat = 76

    // Tints per subgroup. The whole card paints on the `streamTint` (green)
    // because streaming is the primary feature; rent/buy get distinct
    // tints only on their dot + caption so they read as "secondary" modes
    // without fragmenting the overall look of the card.
    private let streamTint: Color = .green
    private let rentTint: Color = .orange
    private let buyTint: Color = .blue

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !flatrates.isEmpty {
                providerGroup(label: "Stream",
                              tint: streamTint,
                              items: flatrates)
            }

            if !rent.isEmpty {
                providerGroup(label: "Rent",
                              tint: rentTint,
                              items: rent)
            }

            if !buy.isEmpty {
                providerGroup(label: "Buy",
                              tint: buyTint,
                              items: buy)
            }

            attribution
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(streamTint.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .strokeBorder(streamTint.opacity(0.22), lineWidth: 0.5)
        }
        .padding(.horizontal)
        .sheet(isPresented: $isJustWatchPresented) {
            WebView(videoURL: justWatchURL)
                .ignoresSafeArea()
        }
    }

    // MARK: - Subgroup

    private func providerGroup(label: String,
                               tint: Color,
                               items: [Flatrate]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Caption row: a tiny coloured dot + the subgroup label. Tight
            // on purpose — the section header already communicates
            // "Available on", so this is just a mode hint (stream vs rent).
            HStack(spacing: 6) {
                Circle()
                    .fill(tint)
                    .frame(width: 7, height: 7)
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(tint)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(items, id: \.providerID) { item in
                        providerTile(item)
                    }
                }
            }
        }
    }

    // MARK: - Tile

    @ViewBuilder
    private func providerTile(_ content: Flatrate) -> some View {
        if let imageURL = content.logoPath,
           let name = content.providerName {

            let url = API.Common.imageUrl(imageId: imageURL)

            VStack(spacing: 8) {
                // Logo in a rounded-square tile. Hairline white stroke gives
                // the tile a visible edge on dark brand marks; a soft shadow
                // lifts it off the tinted card background so each provider
                // reads as its own distinct "app icon".
                GenericImageView(url: url,
                                 width: tileSize,
                                 height: tileSize,
                                 cornerRadius: tileCornerRadius,
                                 showShadow: false)
                    .overlay {
                        RoundedRectangle(cornerRadius: tileCornerRadius,
                                         style: .continuous)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.2), radius: 5, y: 2)

                Text(name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: tileLabelWidth)
            }
        }
    }

    // MARK: - Attribution

    /// Credit line for the data sources. TMDB's terms of use require an
    /// in-app attribution ("This product uses the TMDB API but is not
    /// endorsed or certified by TMDB"), and TMDB's licensing of the
    /// streaming-availability data requires a JustWatch credit alongside.
    /// Both are surfaced here in a compact two-line stack. When a
    /// JustWatch deeplink is available the JustWatch line doubles as a
    /// "take me to where I can watch" action.
    @ViewBuilder
    private var attribution: some View {
        VStack(alignment: .leading, spacing: 4) {
            // JustWatch (interactive when a deeplink exists)
            if justWatchURL != nil {
                Button {
                    isJustWatchPresented = true
                } label: {
                    attributionContent(chevron: true)
                }
                .buttonStyle(.plain)
            } else {
                attributionContent(chevron: false)
            }
        }
    }

    private func attributionContent(chevron: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "info.circle")
                .font(.system(size: 10, weight: .regular))
            Text("Availability provided by JustWatch")
                .font(.system(size: 11, weight: .regular))
            if chevron {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 10, weight: .semibold))
            }
        }
        .foregroundStyle(.secondary)
    }
}
