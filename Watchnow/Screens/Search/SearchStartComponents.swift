//
//  SearchStartComponents.swift
//  Watchnow
//
//  Created by k.christopoulos on 31/8/26.
//
//  The cards, chips and layout helpers the search start screen is built
//  from. Split out of `SearchStartView` so that file reads as the screen's
//  structure rather than as a thousand lines of leaf views.
//

import SwiftUI

// MARK: - TrendingPosterCard

/// Compact poster tile for the trending row.
///
/// Narrower than the home feed's `BottomCard` (108pt vs 150pt) on purpose:
/// this shelf is a shortcut on a screen whose primary action is typing, so
/// it should read as a secondary offer and let four-and-a-bit posters peek
/// in, which is what signals "scrollable" without a chevron.
struct TrendingPosterCard: View {
    let result: Result
    let screenType: ScreenTypes
    let reduceMotion: Bool

    @Namespace private var namespace
    @State private var isPressed = false

    static let posterWidth: CGFloat = 108
    static let posterHeight: CGFloat = 162
    /// Poster + spacing + two text lines, at the default text size. Pinned so
    /// the enclosing ScrollView has a fixed height and the sections below it
    /// don't shift as posters stream in.
    ///
    /// Callers that need the *current* height (the shelf, its skeleton) must
    /// use `scaledTotalHeight` — this constant is the baseline it scales from.
    static let totalHeight: CGFloat = 218

    /// The text budget inside `totalHeight`: title (two lines) + year.
    static let textHeight: CGFloat = 218 - 162 - 7

    private let cornerRadius: CGFloat = AppRadius.card

    /// Grows with the reader's text size so the title isn't clipped inside
    /// the shelf's fixed row height.
    @ScaledMetric(relativeTo: .caption) private var textBox: CGFloat = TrendingPosterCard.textHeight

    private var cardHeight: CGFloat { Self.posterHeight + 7 + textBox }

    var body: some View {
        NavigationLink {
            let model = ContentDetailsModel(screenType: screenType, result: result)
            let vm = ContentDetailsViewModel(model: model)
            ContentDetailsView(detailsViewModel: vm)
                .navigationTransition(.zoom(sourceID: result.id ?? 0, in: namespace))
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                poster
                title
                Spacer(minLength: 0)
            }
            .frame(width: Self.posterWidth, height: cardHeight, alignment: .top)
        }
        .buttonStyle(PressableCardStyle(reduceMotion: reduceMotion))
        .matchedTransitionSource(id: result.id ?? 0, in: namespace)
        .accessibilityLabel(result.getResultTitle())
        .accessibilityHint("Opens details")
    }

    private var poster: some View {
        PosterImage(url: result.getPosterURL(),
                    width: Self.posterWidth * 2,
                    height: Self.posterHeight * 2,
                    cornerRadius: cornerRadius,
                    shadowRadius: 0)
            .frame(width: Self.posterWidth, height: Self.posterHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.30), radius: 5, y: 3)
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(result.getResultTitle())
                .appFont(12, weight: .semibold, relativeTo: .caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            let year = result.getReleaseDate(addSeparator: false)
            if !year.isEmpty {
                Text(year)
                    .appFont(11, relativeTo: .caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: Self.posterWidth, alignment: .leading)
    }
}

// MARK: - PressableCardStyle

/// Spring scale-down on press. Uses a `ButtonStyle` rather than a
/// `DragGesture` so it composes with `NavigationLink` without competing
/// with the scroll view's own gesture recognition.
private struct PressableCardStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}

// MARK: - TrendingSkeletonRow

/// Shimmer placeholder matching `TrendingPosterCard`'s exact geometry, so
/// the real posters land in place instead of nudging the layout when the
/// fetch returns.
struct TrendingSkeletonRow: View {

    @ScaledMetric(relativeTo: .caption) private var textBox: CGFloat = TrendingPosterCard.textHeight

    private var cardHeight: CGFloat { TrendingPosterCard.posterHeight + 7 + textBox }

    var body: some View {
        InlineShimmerContainer {
            // Same ScrollView wrapper as `trendingRow`, not a bare HStack.
            // A bare stack five cards wide overflows the screen and reports
            // that width up to the enclosing vertical ScrollView, which
            // knocked the whole start screen's layout sideways for a frame.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(0..<5, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 7) {
                            ShimmerBox(cornerRadius: AppRadius.card)
                                .frame(width: TrendingPosterCard.posterWidth,
                                       height: TrendingPosterCard.posterHeight)
                            ShimmerBox(cornerRadius: AppRadius.micro)
                                .frame(width: TrendingPosterCard.posterWidth * 0.85, height: 10)
                            ShimmerBox(cornerRadius: AppRadius.micro)
                                .frame(width: TrendingPosterCard.posterWidth * 0.45, height: 9)
                            Spacer(minLength: 0)
                        }
                        .frame(width: TrendingPosterCard.posterWidth,
                               height: cardHeight, alignment: .top)
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollDisabled(true)
        }
        .frame(height: cardHeight, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - GenreBrowseChip

/// Icon + label pill for a browsable genre.
///
/// Tinted rather than neutral so the grid reads as a palette of choices
/// instead of a wall of identical grey pills — but tinted *quietly* (12%
/// fill, hierarchical icon), because unlike `FilterChip` none of these is
/// ever in a selected state on this screen: tapping one leaves for the
/// results list.
struct GenreBrowseChip: View {
    let genre: SearchModel.Genre
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: genre.symbol)
                    .appFont(12, weight: .semibold, relativeTo: .caption)
                    .symbolRenderingMode(.hierarchical)
                Text(genre.name)
                    .appFont(14, weight: .medium, relativeTo: .subheadline)
            }
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 13)
            // 44pt rather than the 34 its own padding produced. These sit in
            // a wrapping grid where neighbours are only 8pt apart, which is
            // exactly the situation a short target mis-fires in.
            .frame(minHeight: 44)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.22), lineWidth: 0.5)
            }
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(GenreChipPressStyle(reduceMotion: reduceMotion))
        .accessibilityLabel("Browse \(genre.name)")
        .accessibilityHint("Shows popular \(genre.name.lowercased()) titles")
    }
}

/// Springy press for the genre chips. Scales further than
/// `ChipPressStyle` because a genre tap navigates away — the extra travel
/// is the acknowledgement that something is about to happen.
struct GenreChipPressStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.93 : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.6),
                       value: configuration.isPressed)
    }
}

// MARK: - RecentSearchChip

/// Chip is split into two side-by-side tap zones so the X is reliably
/// hittable. The previous nested-button layout fought SwiftUI's hit
/// testing — the outer button's tap area swallowed touches near the X.
/// Now both halves are sibling `Button`s sharing a single Capsule
/// background, each with explicit `contentShape` so the entire half is
/// tappable, not just the visible icon/text.
///
/// Both halves are also 44pt tall and the X is 44pt wide, per Apple's
/// minimum. Splitting the chip fixed *which* half a touch landed in, but
/// left the targets at roughly 33×31 — the visual padding was doing the
/// sizing, and a capsule sized to a 14pt label is not 44pt tall. The
/// visible pill keeps its original proportions; the tappable area around
/// it is what grew.
struct RecentSearchChip: View {
    let query: String
    let onTap: () -> Void
    let onRemove: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Apple's minimum comfortable target.
    private static let minimumTarget: CGFloat = 44

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .appFont(12, weight: .regular, relativeTo: .caption)
                        .foregroundStyle(.secondary)
                    Text(query)
                        .appFont(14, weight: .medium, relativeTo: .subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .padding(.leading, 14)
                .padding(.trailing, 6)
                .frame(minHeight: Self.minimumTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(ChipPressStyle(reduceMotion: reduceMotion))
            .accessibilityLabel("Search \(query)")

            // Hairline separator clarifies that the X is its own tap
            // zone — without it the chip reads as one solid pill and
            // the user's finger lands on the text half by default.
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 0.5, height: 20)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .appFont(11, weight: .semibold, relativeTo: .caption2)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: Self.minimumTarget,
                           minHeight: Self.minimumTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ChipPressStyle(reduceMotion: reduceMotion))
            .accessibilityLabel("Remove \(query) from recent searches")
        }
        .background {
            Capsule(style: .continuous)
                .fill(Color(.secondarySystemBackground))
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
        }
        // Chips leave by shrinking into their own centre, so removing one
        // reads as it collapsing out of the flow rather than the whole row
        // re-flowing around a hole.
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }
}

/// Press treatment for the two halves of a recent chip. Scoped tighter
/// than `PressableCardStyle` — a chip is small enough that a 0.94 scale
/// reads as a wobble, so this only dips the opacity and eases the tint.
private struct ChipPressStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: AppMotion.quick),
                       value: configuration.isPressed)
    }
}
