//
//  BottomCard.swift
//  Watchnow
//
//  Created by k.christopoulos on 5/8/21.
//

import SwiftUI
import Kingfisher

/// Standard poster card used in the non-trending sections on the home
/// screen (Most Watched, Coming Soon, Fresh Episodes, …).
///
/// Replaces the older "poster with a dark gradient + title written over it"
/// look with a cleaner stack: crisp poster up top, title + meta row in a
/// dedicated text strip below. The poster stays uncluttered (so cover art
/// actually reads), and the meta strip surfaces year and rating that used
/// to be hidden under the gradient.
struct BottomCard: View {
    var content: Result
    var screenType: ScreenTypes
    @Namespace private var namespace

    init(content: Result, screenType: ScreenTypes) {
        self.screenType = screenType
        self.content = content
    }

    private let posterHeight: CGFloat = 175
    private let posterCornerRadius: CGFloat = 12

    var body: some View {
        NavigationLink {
            let model = ContentDetailsModel(screenType: screenType, result: content)
            let vm = ContentDetailsViewModel(model: model)
            ContentDetailsView(detailsViewModel: vm)
                .navigationTransition(.zoom(sourceID: content.id ?? 0, in: namespace))
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                poster
                metadata
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .matchedTransitionSource(id: content.id ?? 0, in: namespace)
    }

    // MARK: - Poster

    private var poster: some View {
        PosterImage(
            url: content.getPosterURL(),
            width: 260,
            height: 390,
            cornerRadius: posterCornerRadius,
            shadowRadius: 0 // applied below at the card level
        )
        .frame(height: posterHeight)
        .clipShape(RoundedRectangle(cornerRadius: posterCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: posterCornerRadius, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
    }

    // MARK: - Metadata

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(content.getResultTitle())
                .appFont(12, weight: .semibold, relativeTo: .caption)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            metaRow
        }
    }

    /// Rating chip + release year, separated by a dot. Both components are
    /// rendered conditionally so a missing rating or missing date collapses
    /// cleanly instead of leaving a floating separator.
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
                            .foregroundColor(RatingStyle.tint(for: rating))
                        Text(ratingText)
                            .appFont(10, weight: .semibold, relativeTo: .caption2)
                            .foregroundColor(.secondary)
                    }
                }
                if ratingText != nil, year != nil {
                    Text("•")
                        .appFont(10, relativeTo: .caption2)
                        .foregroundColor(.secondary.opacity(0.6))
                }
                if let year {
                    Text(year)
                        .appFont(10, weight: .medium, relativeTo: .caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var rating: Double? {
        guard let rating = content.vote_average, rating > 0 else { return nil }
        return rating
    }

    /// `getReleaseDate(addSeparator: false)` already returns just the year
    /// (the backing implementation drops the `-MM-DD` suffix) or `""` when
    /// there is no release date. The empty-string guard keeps a bare `•`
    /// from rendering next to an orphaned rating.
    private var yearString: String? {
        let raw = content.getReleaseDate(addSeparator: false)
        return raw.isEmpty ? nil : raw
    }
}

// MARK: - RatingStyle

/// Shared rating presentation used by `TopCard`, `BottomCard`, and the
/// search list row so a "7.8" looks the same everywhere it appears.
///
/// Tint follows a three-band ramp: gold for 8+, the regular orange for
/// 6.5–8, and a muted gray for anything lower. Draws the eye toward the
/// genuinely-great titles without turning the list into a traffic light.
///
/// Lives in this file (rather than a standalone file) so it rides along
/// with a view that's already in the Xcode target — no project changes
/// needed to pick it up.
enum RatingStyle {
    static func tint(for rating: Double?) -> Color {
        guard let rating, rating > 0 else { return .gray }
        switch rating {
        case 8.0...:     return Color(red: 0.98, green: 0.76, blue: 0.23) // warm gold
        case 6.5..<8.0:  return .orange
        default:         return Color.gray.opacity(0.85)
        }
    }
}
