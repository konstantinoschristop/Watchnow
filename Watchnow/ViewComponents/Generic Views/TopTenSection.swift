//
//  TopTenSection.swift
//  Watchnow
//
//  "Top 10 of All Time" — the scroll-payoff section at the bottom of
//  each main feed. Visual grammar borrowed from Netflix's "Top 10 in
//  your country" shelf: a horizontal row of cards where each card has
//  a giant outlined rank numeral that *overlaps the left edge of the
//  poster*, so the ranking and the artwork share a single unit. Cards
//  are tall enough that the numeral can breathe (italic, semi-outlined,
//  carrying medal tones for the podium) but the row stays horizontal,
//  matching every other carousel on the screen.
//
//  The earlier vertical stack was abandoned because three vertical-flow
//  sections in a row (hero → list → top-10) destroyed the horizontal
//  rhythm of the feed.
//

import SwiftUI
import Kingfisher

struct TopTenSection<VM: BaseViewModelProtocol>: View {

    let results:     [Result]
    let screenType:  ScreenTypes
    let viewSection: ViewSections
    let viewModel:   VM

    @Namespace private var namespace

    /// 10 entries by definition — extra items past 10 would undermine
    /// the "definitive ranking" feel that earned the section its name.
    private let cap: Int = 10

    private var visibleResults: [Result] {
        // Patch media_type before rendering — Movies/TV endpoints don't
        // populate it, and the navigation push reads it to decide which
        // ContentDetailsView to construct.
        Array(results.prefix(cap)).map { result in
            var r = result
            r.media_type = screenType == .movie ? "movie" : "tv"
            return r
        }
    }

    var body: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(visibleResults.enumerated()), id: \.element) { idx, result in
                        NavigationLink {
                            let model = ContentDetailsModel(screenType: screenType, result: result)
                            let vm = ContentDetailsViewModel(model: model)
                            ContentDetailsView(detailsViewModel: vm)
                                .navigationTransition(.zoom(sourceID: result.id, in: namespace))
                        } label: {
                            TopTenCard(rank: idx + 1, result: result)
                        }
                        .matchedTransitionSource(id: result.id, in: namespace)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
        } header: {
            SectionHeaderView(
                title: viewSection.cleanTitle,
                icon: viewSection.themeIcon,
                tint: viewSection.themeColor,
                showsPulse: viewSection.isTrending
            )
            .textCase(.none)
        }
    }
}

// MARK: - TopTenCard

/// Single ranking card. Layout trick: an `HStack` with **negative spacing**
/// pulls the poster leftward so its left edge sits *over* the right side
/// of the rank numeral, exactly matching Netflix's framing. The poster's
/// shadow does the depth heavy-lifting — it tells the eye "I'm in front"
/// without any explicit z-ordering or masking.
private struct TopTenCard: View {

    let rank: Int
    let result: Result

    private let posterWidth:  CGFloat = 110
    private let posterHeight: CGFloat = 165
    private let numeralSize:  CGFloat = 130

    /// Overlap between the numeral and the poster. Just enough to look
    /// like "the poster is in front" via shadow without the poster
    /// covering up readable glyph data.
    private let overlap: CGFloat = 10

    /// Reserved height for title + meta. Two lines of title at 12pt + the
    /// meta row + spacing — enough to fit any plausible title at 2 lines
    /// and short titles at 1 line, both producing the same outer card
    /// height. Without this fixed reserve, single-line titles produced
    /// shorter cards and the bottom-aligned row laddered.
    private let textBlockHeight: CGFloat = 46

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack(alignment: .bottom, spacing: -overlap) {
                rankNumeral
                poster
            }

            textColumn
                .frame(width: posterWidth,
                       height: textBlockHeight,
                       alignment: .topLeading)
        }
        // No outer .frame(width:) — the card takes whatever the natural
        // numeral width + poster width gives it. #10 ends up ~25pt wider
        // than #1 because the numeral genuinely needs more room. Same
        // tradeoff Netflix makes.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Number \(rank), \(result.getResultTitle())")
    }

    // MARK: - Text column

    /// Title + (rating · year) meta row, kept tight so the card stays
    /// near the same height as the other carousel cards. Reuses the
    /// same `RatingStyle` palette as BottomCard / ListSection so the
    /// rating tint reads consistently across the screen.
    private var textColumn: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(result.getResultTitle())
                .appFont(12, weight: .semibold, relativeTo: .caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            metaRow
        }
    }

    @ViewBuilder
    private var metaRow: some View {
        let year = yearString
        let ratingText = rating.map { String(format: "%.1f", $0) }

        if ratingText != nil || year != nil {
            HStack(spacing: 5) {
                if let ratingText {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .appFont(9, weight: .semibold, relativeTo: .caption2)
                            .foregroundStyle(RatingStyle.tint(for: rating))
                        Text(ratingText)
                            .appFont(10, weight: .semibold, relativeTo: .caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if ratingText != nil, year != nil {
                    Text("•")
                        .appFont(10, relativeTo: .caption2)
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                if let year {
                    Text(year)
                        .appFont(10, weight: .medium, relativeTo: .caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var rating: Double? {
        guard let r = result.vote_average, r > 0 else { return nil }
        return r
    }

    private var yearString: String? {
        let raw = result.getReleaseDate(addSeparator: false)
        return raw.isEmpty ? nil : raw
    }

    // MARK: - Numeral

    /// Italic black numeral with a faint outline. Top-3 paint in medal
    /// tones (gold / silver / bronze) — same colour grammar as the
    /// `TopCard` rank badge — so the two ranking systems feel like one
    /// family. Ranks 4–10 use the brand accent at increasing transparency
    /// so the eye still reads the order at a glance.
    ///
    /// `.fixedSize()` lets the numeral take its natural width — that's
    /// what makes #10 render fully without the prior fixed-slot setup
    /// truncating it to "…". Card widths consequently grow with digit
    /// count, which mirrors the reality of the design (Netflix's #10 is
    /// also visibly wider than its #1).
    private var rankNumeral: some View {
        Text("\(rank)")
            .font(.system(size: numeralSize, weight: .black, design: .rounded))
            .italic()
            .foregroundStyle(rankFill)
            .lineLimit(1)
            .fixedSize()
            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
    }

    /// Gold / silver / bronze for the podium; brand accent for 4-10
    /// at descending opacity so the eye still ranks them visually.
    private var rankFill: Color {
        switch rank {
        case 1: return Color(red: 1.00, green: 0.80, blue: 0.20)
        case 2: return Color(red: 0.80, green: 0.80, blue: 0.85)
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20)
        default:
            // Gradually fade from accent (rank 4 ≈ 0.95) to faded
            // (rank 10 ≈ 0.6). Subtle, but signals "earlier ranks have
            // more weight" without breaking the brand tint.
            let opacity = max(0.6, 1.0 - (Double(rank - 3) * 0.06))
            return .accentColor.opacity(opacity)
        }
    }

    // MARK: - Poster

    private var poster: some View {
        KFImage.url(result.getResultPosterURL())
            .downsampling(size: CGSize(width: 320, height: 480))
            .loadImmediately()
            .fromMemoryCacheOrRefresh()
            .cacheOriginalImage()
            .fade(duration: 0.2)
            .placeholder {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(Color.secondary.opacity(0.15))
                    .overlay {
                        Image(systemName: "film")
                            .appFont(22, weight: .light, relativeTo: .title2)
                            .foregroundStyle(.secondary)
                    }
            }
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: posterWidth, height: posterHeight)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 0.5)
            }
            // Strong shadow so the poster reads as "in front of" the
            // numeral without explicit z-ordering or layering.
            .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
    }
}
