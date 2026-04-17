//
//  GenericListView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 6/8/22.
//

import Foundation
import SwiftUI
import Kingfisher

/// Shared list used by Search and Watchlist.
///
/// Each row is a `ResultRow` — portrait poster, a tinted media-type badge,
/// title, meta line (year + rating), and a short overview snippet. Actor
/// rows drop the rating/overview (none of it exists for a person) and lose
/// their chevron because we don't navigate anywhere for actors yet. Swipe
/// actions are unchanged: left-swipe toggles Watchlist membership.
struct GenericListView: View {

    @Binding var results: [Result]
    let viewModel: any BaseSwipeActionsProtocol
    var namespace: Namespace.ID

    var body: some View {
        ForEach(Array(results.enumerated()), id: \.element) { _, result in
            row(for: result)
                .listRowSeparator(.visible)
                .listRowSeparatorTint(.primary.opacity(0.08))
                .listRowBackground(Color(.background))
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .swipeActions(allowsFullSwipe: true) {
                    swipeActions(for: result)
                }
        }
    }

    /// Wraps actors in a plain container (no push destination) and every
    /// other result in a `NavigationLink`. The chevron is drawn by the row
    /// itself, so the link's default disclosure indicator is hidden.
    @ViewBuilder
    private func row(for result: Result) -> some View {
        if result.getMediaType() == "Actor" {
            ResultRow(result: result)
        } else {
            NavigationLink {
                let screenType: ScreenTypes = result.media_type == "movie" ? .movie : .tv
                let model = ContentDetailsModel(screenType: screenType, result: result)
                let vm = ContentDetailsViewModel(model: model)
                ContentDetailsView(detailsViewModel: vm)
                    .navigationTransition(.zoom(sourceID: result.id, in: namespace))
            } label: {
                ResultRow(result: result)
            }
            .matchedTransitionSource(id: result.id, in: namespace)
        }
    }

    // MARK: - Swipe actions

    @ViewBuilder
    private func swipeActions(for result: Result) -> some View {
        if result.getMediaType() == "Actor" {
            EmptyView()
        } else if WatchlistManager.existsInWatchList(result: result) {
            removeSwipeAction(result: result).tint(.red)
        } else {
            addSwipeAction(result: result).tint(.green)
        }
    }

    @MainActor
    private func addSwipeAction(result: Result) -> some View {
        Button {
            WatchlistManager.addToWatchList(result: result)
            viewModel.showAddedAlert = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } label: {
            Label("Add to Watchlist", systemImage: "bookmark.fill")
        }
    }

    @MainActor
    private func removeSwipeAction(result: Result) -> some View {
        Button {
            withAnimation {
                WatchlistManager.removeFromWatchList(result: result)
                viewModel.itemRemoved(result: result)
                viewModel.showRemovedAlert = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        } label: {
            Label("Remove", systemImage: "trash")
        }
    }
}

// MARK: - ResultRow

/// Single row. Split out from `GenericListView` so the row layout isn't
/// tangled up in list plumbing and can be styled / previewed in isolation.
///
/// No chevron here — `NavigationLink` inside a `List` row draws the
/// system disclosure indicator automatically, so a custom one would
/// double up.
private struct ResultRow: View {
    let result: Result

    private let posterWidth: CGFloat = 64
    private let posterHeight: CGFloat = 96
    private let posterCornerRadius: CGFloat = 10

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            poster
            textColumn
        }
        .contentShape(Rectangle())
    }

    // MARK: Poster

    /// Using `KFImage` directly (not `PosterImage`) so we can pin `.fill`
    /// inside the fixed frame — the wrapper defaults to `.fit` and leaves
    /// letterbox bars inside the rounded corners.
    private var poster: some View {
        KFImage.url(result.getResultPosterURL())
            .downsampling(size: CGSize(width: 256, height: 384))
            .loadImmediately()
            .loadDiskFileSynchronously()
            .fromMemoryCacheOrRefresh()
            .cacheOriginalImage()
            .fade(duration: 0.2)
            .placeholder {
                RoundedRectangle(cornerRadius: posterCornerRadius, style: .continuous)
                    .fill(Color.secondary.opacity(0.15))
                    .overlay {
                        Image(systemName: placeholderIcon)
                            .font(.system(size: 20, weight: .light))
                            .foregroundStyle(.secondary)
                    }
            }
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: posterWidth, height: posterHeight)
            .clipShape(RoundedRectangle(cornerRadius: posterCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: posterCornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
    }

    private var placeholderIcon: String {
        switch result.getMediaType() {
        case "Actor":    return "person.fill"
        case "TV Series": return "tv"
        default:         return "film"
        }
    }

    // MARK: Text column

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            MediaTypeBadge(kind: result.getMediaType())

            Text(result.getResultTitle())
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            metaRow

            if let overview = overviewSnippet {
                Text(overview)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// Year + star rating. Rendered conditionally so a missing piece never
    /// leaves a dangling separator. Actors skip this row entirely since
    /// neither field applies.
    @ViewBuilder
    private var metaRow: some View {
        if result.getMediaType() == "Actor" {
            EmptyView()
        } else {
            let year = yearString
            let ratingText = rating.map { String(format: "%.1f", $0) }

            if ratingText != nil || year != nil {
                HStack(spacing: 6) {
                    if let year {
                        Text(year)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    if ratingText != nil, year != nil {
                        Text("•")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary.opacity(0.5))
                    }
                    if let ratingText {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(RatingStyle.tint(for: rating))
                            Text(ratingText)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private var rating: Double? {
        guard let rating = result.vote_average, rating > 0 else { return nil }
        return rating
    }

    /// `getReleaseDate(addSeparator: false)` trims `-MM-DD` and omits the
    /// baked-in " - " suffix, leaving just the year or `""`.
    private var yearString: String? {
        let raw = result.getReleaseDate(addSeparator: false)
        return raw.isEmpty ? nil : raw
    }

    /// Nils out empty overviews so the row collapses cleanly and never
    /// renders a blank line under the meta row.
    private var overviewSnippet: String? {
        guard let overview = result.overview,
              !overview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return overview
    }
}

// MARK: - MediaTypeBadge

/// Small tinted pill indicating Movie / TV Series / Actor. Colour-codes
/// the row so the media type is readable before the eye even reaches the
/// title — useful in mixed-media lists (search) and still quietly helpful
/// when the list is homogeneous (watchlist).
private struct MediaTypeBadge: View {
    let kind: String

    var body: some View {
        Text(kind.uppercased())
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(0.5)
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background {
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.15))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(tint.opacity(0.35), lineWidth: 0.5)
            }
    }

    private var tint: Color {
        switch kind {
        case "Movie":     return .accentColor
        case "TV Series": return .purple
        case "Actor":     return .orange
        default:          return .secondary
        }
    }
}
