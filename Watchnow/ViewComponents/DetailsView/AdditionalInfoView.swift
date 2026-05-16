//
//  AdditionalInfoView.swift
//  Watchnow
//
//  About-the-title metadata block. Replaces the previous DisclosureGroup
//  layout (collapsed by default, awkward "title: value" stacks once
//  expanded) with a flat, always-visible composition that mirrors how
//  apps like the App Store and IMDB present metadata: a horizontal stats
//  bar for the at-a-glance facts (release date, runtime, budget, etc.),
//  then a small set of label-over-value rows for the long-form fields
//  (Created By, Languages, Homepage).
//
//  Why no disclosure: the data is already filtered to non-nil fields
//  upstream (each accessor on `ResultDetailsResponse` returns nil when
//  empty), so the section organically shrinks for thinly-documented
//  titles. Hiding it behind a tap added friction without saving space.
//

import SwiftUI

struct AdditionalInfoView: View {

    let details: ResultDetailsResponse
    @State private var isHomepagePresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader

            if let tagline = details.getTagline(), !tagline.isEmpty {
                taglineRow(tagline)
            }

            if !statTiles.isEmpty {
                statsGrid
            }

            longFormRows
        }
        .padding(.horizontal, 16)
        .sheet(isPresented: $isHomepagePresented) {
            WebViewSheet(url: URL(string: details.homepage ?? ""))
        }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 26, height: 26)

            Text("About")
                .font(.system(size: 25, weight: .heavy))
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Tagline

    /// Sits between the header and the stats bar. Italicised + secondary
    /// because it's editorial flavour, not a fact users should read first.
    private func taglineRow(_ tagline: String) -> some View {
        Text("\u{201C}\(tagline)\u{201D}")
            .font(.system(size: 15, weight: .regular, design: .serif))
            .italic()
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(3)
    }

    // MARK: - Stats grid

    /// Adaptive 2-column grid of compact stat tiles. Minimum tile width
    /// of 150pt fits 2 columns on a regular iPhone and flows naturally
    /// to 3+ columns on iPad / landscape — no per-device branching.
    /// Beats a horizontal scroll for "scan everything at once".
    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)],
                  alignment: .leading,
                  spacing: 10) {
            ForEach(statTiles, id: \.label) { tile in
                StatTile(label: tile.label, value: tile.value)
            }
        }
    }

    private var statTiles: [Stat] {
        var tiles: [Stat] = []
        if let date = details.getDate() {
            tiles.append(.init(label: "Released",  value: date))
        }
        if let runtime = details.getRuntime() {
            tiles.append(.init(label: "Runtime",   value: runtime))
        }
        // Status is informative for TV ("Returning Series", "Ended",
        // "Canceled") but redundant for movies (almost always "Released"
        // by the time anyone's looking at the details). Detect TV via
        // `number_of_seasons` — only series populate it.
        if isSeries, let status = details.status, !status.isEmpty {
            tiles.append(.init(label: "Status",    value: status))
        }
        if let budget = details.getBudget() {
            tiles.append(.init(label: "Budget",    value: budget))
        }
        if let revenue = details.getRevenue() {
            tiles.append(.init(label: "Revenue",   value: revenue))
        }
        return tiles
    }

    private var isSeries: Bool {
        details.number_of_seasons != nil
    }

    private struct Stat {
        let label: String
        let value: String
    }

    // MARK: - Long-form rows

    /// "Created By", "Spoken Languages", "Homepage" — fields that don't
    /// fit in a compact tile because their values can wrap to multiple
    /// lines. Rendered as label-on-top, value-below pairs.
    @ViewBuilder
    private var longFormRows: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let createdBy = details.getCreatedBy(), !createdBy.isEmpty {
                LabelledRow(label: "Created By", value: createdBy.joined(separator: ", "))
            }

            if let languages = details.getLanguages(), !languages.isEmpty {
                LabelledRow(label: "Languages",  value: languages.joined(separator: ", "))
            }

            if let homepage = details.homepage, !homepage.isEmpty {
                LabelledLinkRow(label: "Homepage", value: homepage) {
                    isHomepagePresented = true
                }
            }
        }
    }
}

// MARK: - StatTile

/// Compact card: small uppercase label on top, prominent value below.
/// Tile width is content-driven so a 4-character "Status" tile doesn't
/// take the same room as a longer "$1,234,567,890" revenue value, but a
/// minimum width keeps the row from collapsing into uneven shards.
private struct StatTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minWidth: 90, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        }
    }
}

// MARK: - Long-form rows

private struct LabelledRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Same shape as `LabelledRow` but the value renders as a tappable link
/// styled in the accent colour. Used for the homepage row, which opens
/// in an in-app `WebView` sheet.
private struct LabelledLinkRow: View {
    let label: String
    let value: String
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Button(action: onTap) {
                HStack(spacing: 4) {
                    Text(value)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.accentColor)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
