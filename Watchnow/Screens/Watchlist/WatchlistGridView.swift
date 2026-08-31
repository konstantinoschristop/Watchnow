//
//  WatchlistGridView.swift
//  Watchnow
//
//  Created by k.christopoulos on 31/8/26.
//

import SwiftUI
import Kingfisher

/// Poster-wall presentation of the watchlist.
///
/// The list view shows one title per screen-width row, which spends most
/// of the screen on an overview snippet nobody re-reads for something they
/// already chose to save. A saved list is a collection, and a collection
/// is recognised by its covers — three across puts a dozen titles in view
/// at once and makes the screen look like a shelf rather than a queue.
///
/// The row view is still one tap away via the layout toggle, and it keeps
/// the two things a grid can't do as well: swipe actions and
/// drag-to-reorder.
struct WatchlistGridView<Header: View>: View {

    let items: [Result]
    /// Resolves a title's folder for the corner badge. `nil` while a single
    /// folder is selected, where every badge would say the same thing.
    let folderProvider: ((Int) -> Folder?)?
    let onMoveToFolder: (Result) -> Void
    let onRemove: (Result) -> Void

    var namespace: Namespace.ID
    /// Identity for the poster wall alone. Changing it swaps the covers as
    /// one unit while leaving the header untouched — keying the whole
    /// scroll view instead tore the folder picker down and rebuilt it on
    /// every folder change, which read as the screen jumping.
    var contentID: AnyHashable = 0
    /// Shown in place of the wall when the active folder has nothing in
    /// it. Rendered inside this scroll view rather than by the caller, so
    /// the header sits at exactly the same height either way.
    var emptyState: AnyView? = nil
    /// Scrolls with the grid rather than sitting pinned above it. Supplied
    /// by the caller so this view doesn't need to know it's a folder picker.
    @ViewBuilder var header: () -> Header

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Three across. Two makes the posters bigger than the artwork can
    /// carry at typical TMDB resolutions; four drops the titles below a
    /// readable size on a 6.1" phone.
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    }

    var body: some View {
        ScrollView {
            header()

            Group {
                if items.isEmpty, let emptyState {
                    emptyState
                        .padding(.top, 40)
                } else {
                    wall
                }
            }
            .id(contentID)
            .transition(reduceMotion
                        ? .opacity
                        : .opacity.combined(with: .offset(y: 10)))

            if !items.isEmpty {
                InlineBannerSection()
                    .padding(.top, 20)
            }
        }
    }

    private var wall: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
            ForEach(items, id: \.self) { result in
                WatchlistPosterCell(result: result,
                                    folder: folder(for: result),
                                    namespace: namespace,
                                    reduceMotion: reduceMotion,
                                    onMoveToFolder: { onMoveToFolder(result) },
                                    onRemove: { onRemove(result) })
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private func folder(for result: Result) -> Folder? {
        guard let provider = folderProvider, let id = result.id else { return nil }
        return provider(id)
    }
}

// MARK: - WatchlistPosterCell

/// One title in the poster wall: cover, name, and a compact meta line.
private struct WatchlistPosterCell: View {

    let result: Result
    let folder: Folder?
    var namespace: Namespace.ID
    let reduceMotion: Bool
    let onMoveToFolder: () -> Void
    let onRemove: () -> Void

    @State private var confirmingRemove = false

    private let cornerRadius: CGFloat = 12

    var body: some View {
        NavigationLink {
            let screenType: ScreenTypes = result.media_type == "movie" ? .movie : .tv
            let model = ContentDetailsModel(screenType: screenType, result: result)
            let vm = ContentDetailsViewModel(model: model)
            ContentDetailsView(detailsViewModel: vm)
                .navigationTransition(.zoom(sourceID: result.id ?? 0, in: namespace))
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                poster
                title
                metaLine
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PosterPressStyle(reduceMotion: reduceMotion))
        .matchedTransitionSource(id: result.id ?? 0, in: namespace)
        // A grid cell has no edges to swipe, so the row view's swipe
        // actions move into a long-press menu here. Both routes end up in
        // the same handlers the list uses.
        .contextMenu {
            Button {
                onMoveToFolder()
            } label: {
                Label("Move to Folder", systemImage: "folder")
            }
            Button(role: .destructive) {
                confirmingRemove = true
            } label: {
                Label("Remove from Watchlist", systemImage: "bookmark.slash")
            }
        }
        .confirmationDialog("Remove \(result.getResultTitle()) from your Watchlist?",
                            isPresented: $confirmingRemove,
                            titleVisibility: .visible) {
            Button("Remove", role: .destructive) { onRemove() }
            Button("Cancel", role: .cancel) { }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Opens details")
    }

    // MARK: Poster

    /// The cover, in a box whose size does not depend on the cover.
    ///
    /// The aspect ratio is carried by the `Rectangle` underneath and the
    /// artwork is layered on top, rather than the other way round. Putting
    /// `.aspectRatio` on the image itself looked equivalent but wasn't: an
    /// unloaded `KFImage` reports a zero ideal size, and in a `LazyVGrid`
    /// cell — where the proposed height is unspecified — `.fit` has nothing
    /// to derive a height from, so the whole tile collapsed to nothing
    /// until the art decoded and then snapped open. A shape accepts any
    /// proposal, so the slot is the right size from the first frame whether
    /// the image arrives in 20ms, in two seconds, or never.
    ///
    /// Drawn with `KFImage` directly rather than through `PosterImage`
    /// because that wrapper hardcodes `.fit`, which letterboxes the covers
    /// TMDB doesn't crop to exactly 2:3 — the same reason `ResultRow`
    /// bypasses it.
    private var poster: some View {
        Rectangle()
            .fill(Color(.tertiarySystemFill))
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .overlay {
                KFImage.url(result.getResultPosterURL())
                    .downsampling(size: CGSize(width: 320, height: 480))
                    .loadImmediately()
                    .fromMemoryCacheOrRefresh()
                    .cacheOriginalImage()
                    .fade(duration: 0.25)
                    .placeholder { placeholderArt }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
            }
            .overlay(alignment: .topLeading) { typeBadge }
            .overlay(alignment: .topTrailing) { folderBadge }
            .shadow(color: .black.opacity(0.28), radius: 5, y: 3)
    }

    /// Stand-in for a cover that hasn't arrived — or never will, for the
    /// handful of titles TMDB has no artwork for. A type glyph rather than
    /// a bare grey tile, so a permanently missing poster reads as "no
    /// artwork" instead of as a broken cell.
    private var placeholderArt: some View {
        Image(systemName: MediaTypeBadge.symbol(for: result.getMediaType()))
            .font(.system(size: 24, weight: .light))
            .foregroundStyle(.secondary)
    }

    /// Movie or series, as a glyph on the cover itself.
    ///
    /// The meta line below already says which it is, but in a wall of
    /// covers that line is 11pt and easy to skip — you end up reading each
    /// cell to sort the films from the shows. On the artwork it registers
    /// without reading.
    ///
    /// Same neutral treatment as the folder badge, and sitting in the
    /// opposite corner, so the two read as a matched pair of markers rather
    /// than competing for attention. White on a dark scrim rather than a
    /// tint, because poster art is arbitrary and a translucent colour would
    /// land on anything from black to white.
    private var typeBadge: some View {
        Image(systemName: MediaTypeBadge.symbol(for: result.getMediaType()))
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background {
                Circle().fill(.black.opacity(0.55))
            }
            .overlay {
                Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
            }
            .padding(5)
            .accessibilityHidden(true)
    }

    /// Which folder this title is filed in, as a glyph in the cover's
    /// corner. Only drawn in the "All" view — the caller passes `nil`
    /// inside a folder, where every badge would be identical.
    @ViewBuilder
    private var folderBadge: some View {
        if let folder {
            Image(systemName: folder.symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background {
                    Circle().fill(.black.opacity(0.55))
                }
                .overlay {
                    Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
                }
                .padding(5)
        }
    }

    // MARK: Text

    private var title: some View {
        Text(result.getResultTitle())
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            // Reserves both lines up front so cells with one-line titles
            // don't sit higher than their neighbours in the same row.
            .frame(height: 32, alignment: .top)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Media type + year + rating, compressed to one line. The type is a
    /// glyph rather than the row view's "MOVIE"/"TV SERIES" pill — at this
    /// width the pill would consume the whole line on its own.
    ///
    /// Titles saved by older builds (and anything arriving through iCloud
    /// from one) carry only id, name, type and poster path — no date, no
    /// score. Falling back to the type spelled out keeps those cells from
    /// showing a lone unexplained glyph floating under the title.
    private var metaLine: some View {
        HStack(spacing: 4) {
            Image(systemName: MediaTypeBadge.symbol(for: result.getMediaType()))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)

            if hasFacts {
                if !year.isEmpty {
                    Text(year)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                if let rating {
                    if !year.isEmpty {
                        Text("·")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.yellow)
                    Text(rating)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            } else {
                Text(result.media_type == "tv" ? "Series" : "Movie")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    private var hasFacts: Bool {
        !year.isEmpty || rating != nil
    }

    private var year: String {
        result.getReleaseDate(addSeparator: false)
    }

    /// Hidden when TMDB has no votes yet — "0.0" reads as a terrible film
    /// rather than as an unrated one.
    private var rating: String? {
        guard let average = result.vote_average, average > 0 else { return nil }
        return String(format: "%.1f", average)
    }

    private var accessibilityDescription: String {
        var parts = [result.getResultTitle(), result.getMediaType()]
        if !year.isEmpty { parts.append(year) }
        if let rating { parts.append("rated \(rating)") }
        if let folder { parts.append("in \(folder.name)") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - PosterPressStyle

/// Spring push on the cover. A `ButtonStyle` rather than a gesture so it
/// composes with `NavigationLink` without competing with the scroll view's
/// own recognisers.
private struct PosterPressStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}
