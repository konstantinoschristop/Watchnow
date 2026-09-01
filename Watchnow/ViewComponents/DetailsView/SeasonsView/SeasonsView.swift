//
//  SeasonsView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 12/8/22.
//
//  Horizontal scrolling grid of season tiles on the details screen.
//  Tapping a tile selects that season and opens the episodes sheet —
//  both driven by bindings passed in from ContentDetailsView so that
//  the "See all" button and individual tile taps share the same state.
//

import SwiftUI

struct SeasonsView: View {

    var seasons: [Season]
    var navBarTitle: String
    var seriesID: Int
    @Binding var selectedSeason: Season
    @Binding var isSheetPresented: Bool

    init(seasons: [Season],
         navBarTitle: String,
         seriesID: Int,
         selectedSeason: Binding<Season>,
         isSheetPresented: Binding<Bool>) {

        self.seasons = seasons
        self.navBarTitle = navBarTitle
        self.seriesID = seriesID
        _selectedSeason = selectedSeason
        _isSheetPresented = isSheetPresented
    }

    /// Fixed-height rows so every tile occupies the same vertical space,
    /// regardless of how many lines its label needs. The previous
    /// `.flexible()` rows stretched to fill, so a tile with 2 lines of
    /// metadata next to one with 1 line caused the shorter tile to render
    /// inside an oversized cell with awkward trailing whitespace.
    private static let rowHeight: CGFloat = 64
    private static let tileWidth: CGFloat = 200

    func calculateRowsForSeasons() -> [GridItem] {
        let row = GridItem(.fixed(Self.rowHeight),
                           spacing: 8,
                           alignment: .leading)
        switch seasons.count {
        case 1...2:  return Array(repeating: row, count: 1)
        case 3...10: return Array(repeating: row, count: 2)
        default:     return Array(repeating: row, count: 3)
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: calculateRowsForSeasons(), spacing: 8) {
                ForEach(seasons, id: \.self) { season in
                    if season.name?.isEmpty == false {
                        Button {
                            selectedSeason = season
                            isSheetPresented = true
                        } label: {
                            constructSeason(season)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    /// Tile width is fixed so every season visually aligns across rows;
    /// poster height matches the row height (minus inset) so the artwork
    /// fills the tile from edge to edge.
    func constructSeason(_ season: Season) -> some View {
        HStack(spacing: 10) {
            poster(for: season)

            VStack(alignment: .leading, spacing: 2) {
                Text(season.name ?? "")
                    .appFont(13, weight: .semibold, relativeTo: .footnote)
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                if let episodes = season.episode_count {
                    Text("\(episodes) episode\(episodes == 1 ? "" : "s")")
                        .appFont(11, relativeTo: .caption2)
                        .foregroundStyle(.secondary)
                }

                if let airDate = season.getAirDate() {
                    Text(airDate)
                        .appFont(11, relativeTo: .caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .frame(width: Self.tileWidth, height: Self.rowHeight)
        .background(Color(.secondaryBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    @ViewBuilder
    private func poster(for season: Season) -> some View {
        let posterWidth: CGFloat = 34
        let posterHeight: CGFloat = Self.rowHeight - 16

        if let imageURL = season.poster_path {
            let url = API.Common.imageUrl(imageId: imageURL)
            GenericImageView(url: url,
                             width: posterWidth,
                             height: posterHeight,
                             cornerRadius: AppRadius.micro,
                             showShadow: false)
                .aspectRatio(contentMode: .fill)
                .frame(width: posterWidth, height: posterHeight)
                .clipped()
        } else {
            RoundedRectangle(cornerRadius: AppRadius.micro)
                .fill(Color.gray.opacity(0.25))
                .frame(width: posterWidth, height: posterHeight)
        }
    }
}
