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
/// rows drop the rating/overview (none of it applies to a person) and open
/// `PersonSheetView` on tap instead of pushing a full details screen.
/// Swipe actions are unchanged: left-swipe toggles Watchlist membership.
struct GenericListView: View {

    @Binding var results: [Result]
    let viewModel: any BaseSwipeActionsProtocol
    var namespace: Namespace.ID
    /// When non-nil, adds a "Move to folder" leading-swipe action to each
    /// in-watchlist row. Only the Watchlist screen passes this — Search
    /// results leave it nil so their rows keep a single trailing
    /// Add / Remove action.
    var onMoveToFolder: ((Result) -> Void)? = nil
    /// When non-nil, enables drag-to-reorder via SwiftUI's `.onMove`.
    /// Receives the IndexSet of dragged rows + the destination offset, in
    /// terms of the currently-displayed `results` array. Watchlist passes
    /// this only when the active sort is Date Added (other sorts would
    /// overwrite the move on next re-sort, which would feel broken).
    var onReorder: ((IndexSet, Int) -> Void)? = nil
    /// When non-nil, the row's meta line shows a small badge identifying
    /// which folder the item is in. Watchlist passes this only when the
    /// "All" filter is active — when filtering by folder, every row is in
    /// the same folder, so the badge would be visual noise.
    var folderProvider: ((Int) -> Folder?)? = nil
    /// When non-nil, splices a single native ad row in at this index. Only
    /// Search passes it — the Watchlist is the user's own saved list, and an
    /// ad in the middle of it reads as intrusive rather than as content.
    /// Ignored when there aren't enough results to reach the slot.
    var adSlot: Int? = nil

    var body: some View {
        if let adSlot, adSlot < results.count {
            // Ad-bearing layout. Reordering isn't offered on this path (only
            // the Watchlist reorders, and it never passes `adSlot`), so the
            // split into two ForEach blocks can't disturb `.onMove`.
            ForEach(Array(results.prefix(adSlot)), id: \.self) { configuredRow($0) }

            NativeAdRow()
                .listRowSeparator(.hidden)
                .listRowBackground(Color(.background))
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

            ForEach(Array(results.dropFirst(adSlot)), id: \.self) { configuredRow($0) }
        } else {
            ForEach(Array(results.enumerated()), id: \.element) { _, result in
                configuredRow(result)
            }
            .onMove(perform: onReorder)
        }
    }

    /// A result row with its list styling and swipe actions applied.
    @ViewBuilder
    private func configuredRow(_ result: Result) -> some View {
        row(for: result)
            .listRowSeparator(.visible)
            .listRowSeparatorTint(.primary.opacity(0.08))
            .listRowBackground(Color(.background))
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                leadingSwipeActions(for: result)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                trailingSwipeActions(for: result)
            }
    }

    /// Wraps actors in a tappable `ActorRow` that opens `PersonSheetView`,
    /// and every other result in a `NavigationLink`. The chevron is drawn
    /// by the row itself, so the link's default disclosure indicator is hidden.
    @ViewBuilder
    private func row(for result: Result) -> some View {
        if result.isPerson {
            ActorRow(result: result)
        } else {
            NavigationLink {
                let screenType: ScreenTypes = result.media_type == "movie" ? .movie : .tv
                let model = ContentDetailsModel(screenType: screenType, result: result)
                let vm = ContentDetailsViewModel(model: model)
                ContentDetailsView(detailsViewModel: vm)
                    .navigationTransition(.zoom(sourceID: result.id, in: namespace))
            } label: {
                ResultRow(result: result, folderBadge: folderBadge(for: result))
            }
            .matchedTransitionSource(id: result.id, in: namespace)
        }
    }

    /// Resolve the small meta-line folder badge for a row, if one is
    /// configured and the item belongs to a folder.
    private func folderBadge(for result: Result) -> ResultRow.FolderBadge? {
        guard let provider = folderProvider,
              let id = result.id,
              let folder = provider(id) else {
            return nil
        }
        return ResultRow.FolderBadge(symbol: folder.symbol, name: folder.name)
    }

    // MARK: - Swipe actions

    /// Leading swipe — non-destructive secondary actions. Currently just
    /// "Move to folder", available only on watchlist rows when a move
    /// handler is wired up.
    @ViewBuilder
    private func leadingSwipeActions(for result: Result) -> some View {
        if !result.isPerson,
           WatchlistManager.existsInWatchList(result: result),
           let onMoveToFolder {
            Button {
                onMoveToFolder(result)
            } label: {
                Label("Move", systemImage: "folder")
            }
            .tint(.indigo)
        }
    }

    /// Trailing swipe — the primary Add / Remove action.
    @ViewBuilder
    private func trailingSwipeActions(for result: Result) -> some View {
        if result.isPerson {
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
            let added = WatchlistManager.addToWatchList(result: result)
            viewModel.showAddedAlert = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if added {
                ReviewRequestManager.recordWatchlistAdd()
                ReviewRequestManager.requestReviewIfAppropriate()
            }
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

// MARK: - Actor row

/// Self-contained row for person results. Tapping opens `PersonSheetView`
/// as a medium/large sheet — no navigation push needed for a lightweight
/// biography peek.
private struct ActorRow: View {

    let result: Result
    @State private var isSheetPresented = false

    var body: some View {
        Button {
            guard let path = result.profile_path, !path.isEmpty else { return }
            isSheetPresented = true
        } label: {
            ResultRow(result: result)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isSheetPresented) {
            PersonSheetView(
                personID:    result.id ?? 0,
                name:        result.getResultTitle(),
                profilePath: result.profile_path,
                knownFor:    result.known_for
            )
            // 70% gives a clear glimpse of the Known For row without
            // forcing a scroll, but still leaves the underlying details
            // screen visible at the top so the sheet feels like a peek.
            .presentationDetents([.fraction(0.7), .large])
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
struct ResultRow: View {

    /// Optional small badge appended to the meta line, used by the
    /// Watchlist's "All" view to surface which folder a row belongs to.
    struct FolderBadge {
        let symbol: String
        let name: String
    }

    let result: Result
    var folderBadge: FolderBadge? = nil

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
            .fromMemoryCacheOrRefresh()
            .cacheOriginalImage()
            .fade(duration: 0.2)
            .placeholder {
                RoundedRectangle(cornerRadius: posterCornerRadius, style: .continuous)
                    .fill(Color.secondary.opacity(0.15))
                    .overlay {
                        Image(systemName: placeholderIcon)
                            .appFont(20, weight: .light, relativeTo: .title3)
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
        if result.isPerson { return "person.fill" }
        return result.inferredScreenType == .tv ? "tv" : "film"
    }

    /// What the row's pill should say. A person is a person; everything
    /// else is resolved through `inferredScreenType` so an untagged saved
    /// title is labelled by what it actually is rather than by the
    /// "Actor" fall-through in `getMediaType()`.
    private var badgeKind: String {
        if result.isPerson { return "Actor" }
        return result.inferredScreenType == .tv ? "TV Series" : "Movie"
    }

    // MARK: Text column

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            MediaTypeBadge(kind: badgeKind)

            Text(result.getResultTitle())
                .appFont(16, weight: .semibold, relativeTo: .body)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            metaRow

            if let overview = overviewSnippet {
                Text(overview)
                    .appFont(13, relativeTo: .footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// Year + star rating + optional folder badge. Rendered conditionally
    /// so a missing piece never leaves a dangling separator. Actors skip
    /// this row entirely since none of the fields apply.
    @ViewBuilder
    private var metaRow: some View {
        if result.isPerson {
            EmptyView()
        } else {
            let year = yearString
            let ratingText = rating.map { String(format: "%.1f", $0) }
            let hasYear = year != nil
            let hasRating = ratingText != nil
            let hasBadge = folderBadge != nil

            if hasYear || hasRating || hasBadge {
                HStack(spacing: 6) {
                    if let year {
                        Text(year)
                            .appFont(12, weight: .medium, relativeTo: .caption)
                            .foregroundStyle(.secondary)
                    }
                    if hasYear, hasRating {
                        metaSeparator
                    }
                    if let ratingText {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .appFont(10, weight: .semibold, relativeTo: .caption2)
                                .foregroundStyle(RatingStyle.tint(for: rating))
                            Text(ratingText)
                                .appFont(12, weight: .semibold, relativeTo: .caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if hasBadge, hasYear || hasRating {
                        metaSeparator
                    }
                    if let folderBadge {
                        folderPill(folderBadge)
                    }
                }
            }
        }
    }

    private var metaSeparator: some View {
        Text("•")
            .appFont(12, relativeTo: .caption)
            .foregroundStyle(.secondary.opacity(0.5))
    }

    /// Tinted pill: folder icon + name. Reads as "this item lives in
    /// folder X" — visually distinct from year/rating so the eye doesn't
    /// mistake it for another piece of metadata.
    private func folderPill(_ badge: FolderBadge) -> some View {
        HStack(spacing: 3) {
            Image(systemName: badge.symbol)
                .appFont(10, weight: .semibold, relativeTo: .caption2)
            Text(badge.name)
                .appFont(11, weight: .semibold, relativeTo: .caption2)
                .lineLimit(1)
        }
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background {
            Capsule(style: .continuous)
                .fill(Color.accentColor.opacity(0.12))
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 0.5)
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

/// Quiet outlined pill indicating Movie / TV Series / Actor.
///
/// Deliberately uncoloured. A tinted version — accent for movies, purple
/// for series, matching the two home tabs — was tried and rejected: the
/// palette is already carrying the tab identity and the selected-chip
/// state, and spending it again on a per-row label made mixed lists busy
/// without telling the reader anything the word doesn't.
///
/// The glyph is the part that earns its place. At this size the word alone
/// has to be *read* to be understood, whereas a film reel or a television
/// registers peripherally, which is what makes a mixed search result or
/// watchlist scannable rather than parseable.
struct MediaTypeBadge: View {
    let kind: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: MediaTypeBadge.symbol(for: kind))
                .appFont(9, weight: .bold, relativeTo: .caption2)
            Text(label)
                .appFont(10, weight: .bold, relativeTo: .caption2, design: .rounded)
                .tracking(0.5)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind)
    }

    /// Shorter than `getMediaType()`'s wording — "TV SERIES" pushes the
    /// pill past the width a narrow row or a grid cell can spare, and
    /// "SERIES" loses nothing sitting next to a television glyph.
    private var label: String {
        switch kind {
        case "TV Series": return "SERIES"
        case "Actor":     return "ACTOR"
        default:          return "MOVIE"
        }
    }

    private static func symbol(for kind: String) -> String {
        switch kind {
        case "TV Series": return "tv.fill"
        case "Actor":     return "person.fill"
        default:          return "film.fill"
        }
    }
}
