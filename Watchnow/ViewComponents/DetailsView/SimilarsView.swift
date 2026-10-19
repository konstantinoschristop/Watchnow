//
//  SimilarsView.swift
//  Watchnow
//
//  The horizontal row under "More like this" / "Similar" / "Collection" on
//  the details screen.
//
//  Its own card rather than the home feed's `BottomCard`, because here the
//  row is the last stop on a page someone has scrolled to the end of — it
//  should make the next tap easy and a little fun:
//
//   - The rating sits on the poster in a frosted badge, and titles already
//     in the user's list carry a bookmark, so the row answers "is it any
//     good / have I got it" before a tap.
//   - Long-press for a large preview with Watch Later (or Remove), so a
//     title can be saved without leaving this one.
//   - Cards at the edges turn slightly toward the middle, coverflow-style,
//     and the row snaps card by card. The effect follows the row's own
//     horizontal position only, so the page's vertical scroll can't make it
//     jitter — the reason the home card here used to be static.
//

import SwiftUI

struct SimilarsView: View {

    let content: [Result]
    let screenType: ScreenTypes
    /// Shared with the cards below and with the details screen they push, so
    /// the zoom transition matches.
    var namespace: Namespace.ID

    /// The card the user tapped. Local to this row: the details screen it
    /// pushes is just another `ContentDetailsView`.
    @State private var selection: Selection?
    /// Ids of titles in the watchlist, so the bookmark badges and the
    /// context menu stay in step with saves made from this row.
    @State private var savedIDs: Set<Int> = []

    private struct Selection: Identifiable, Hashable {
        let result: Result
        var id: Int { result.id ?? 0 }
    }

    static let cardWidth: CGFloat = 128
    static let posterHeight: CGFloat = 192

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(Array(content.enumerated()), id: \.element) { index, item in
                    // One native ad, slotted in like another poster card.
                    if index == 3 {
                        // The whole ad in one card, two posters wide and as
                        // tall as a card with its title — see
                        // `NativeAdCard.Layout.sponsored`.
                        NativeAdCard(posterHeight: Self.posterHeight,
                                     layout: .sponsored,
                                     cardWidth: Self.cardWidth * 2 + 12,
                                     cardHeight: Self.posterHeight + 52)
                            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                    }
                    SimilarCard(result: item,
                                isSaved: item.id.map(savedIDs.contains) ?? false,
                                namespace: namespace,
                                onSelect: { selection = Selection(result: $0) },
                                onToggleSave: { toggleSave(item) })
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content
                                .rotation3DEffect(.degrees(phase.value * -16),
                                                  axis: (x: 0, y: 1, z: 0),
                                                  perspective: 0.6)
                                .scaleEffect(phase.isIdentity ? 1 : 0.92)
                        }
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
        .onAppear(perform: refreshSaved)
        .navigationDestination(item: $selection) { selected in
            let model = ContentDetailsModel(screenType: screenType, result: selected.result)
            ContentDetailsView(detailsViewModel: ContentDetailsViewModel(model: model))
                .navigationTransition(.zoom(sourceID: CardTransitionID(selected.result), in: namespace))
        }
    }

    private func refreshSaved() {
        savedIDs = Set(content.filter(WatchlistManager.existsInWatchList(result:)).compactMap(\.id))
    }

    private func toggleSave(_ result: Result) {
        guard let id = result.id else { return }
        var item = result
        // Saved from here the item has no `media_type` of its own; the
        // watchlist needs it to tell a movie from a series with the same id.
        item.media_type = screenType == .tv ? "tv" : "movie"
        if savedIDs.contains(id) {
            WatchlistManager.removeFromWatchList(result: item)
            savedIDs.remove(id)
        } else {
            _ = WatchlistManager.addToWatchList(result: item)
            savedIDs.insert(id)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Card

private struct SimilarCard: View {

    let result: Result
    let isSaved: Bool
    let namespace: Namespace.ID
    let onSelect: (Result) -> Void
    let onToggleSave: () -> Void

    var body: some View {
        Button {
            onSelect(result)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                poster(width: SimilarsView.cardWidth, height: SimilarsView.posterHeight)
                    .overlay(alignment: .topLeading) { ratingBadge }
                    .overlay(alignment: .topTrailing) { savedBadge }

                Text(result.getResultTitle())
                    .appFont(13, weight: .semibold, relativeTo: .footnote)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let year {
                    Text(year)
                        .appFont(12, relativeTo: .caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: SimilarsView.cardWidth, alignment: .leading)
        }
        .buttonStyle(CarouselPressStyle())
        .matchedTransitionSource(id: CardTransitionID(result), in: namespace)
        .contextMenu {
            Button(action: onToggleSave) {
                if isSaved {
                    Label("Remove from Watchlist", systemImage: "bookmark.slash")
                } else {
                    Label("Watch Later", systemImage: "bookmark")
                }
            }
        } preview: {
            poster(width: 260, height: 390)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private func poster(width: CGFloat, height: CGFloat) -> some View {
        RemoteImage(url: posterURL)
            .frame(width: width, height: height)
            .clipShape(AppRadius.shape(AppRadius.panel))
            .overlay {
                AppRadius.shape(AppRadius.panel)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
            }
            .background {
                AppRadius.shape(AppRadius.panel)
                    .fill(Color(.tertiarySystemFill))
                    .shadow(color: .black.opacity(0.22), radius: 8, y: 4)
            }
    }

    @ViewBuilder
    private var ratingBadge: some View {
        if let rating = result.vote_average, rating > 0 {
            HStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .foregroundStyle(RatingStyle.tint(for: rating))
                Text(rating.ratingText)
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            .appFont(11, weight: .bold, relativeTo: .caption2)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
            .environment(\.colorScheme, .dark)
            .padding(7)
        }
    }

    @ViewBuilder
    private var savedBadge: some View {
        if isSaved {
            Image(systemName: "bookmark.fill")
                .appFont(11, weight: .bold, relativeTo: .caption2)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor, in: Circle())
                .padding(7)
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel(Text("Saved", comment: "Button state: the title is in the watchlist"))
        }
    }

    /// w342: a 128pt card needs no more, and the full-size masters several
    /// cards at once would decode to tens of megabytes.
    private var posterURL: URL? {
        guard let path = result.poster_path ?? result.backdrop_path, !path.isEmpty else { return nil }
        return URL(string: API.Common.imageUrl(imageId: path, width: .poster))
    }

    private var year: String? {
        let raw = result.release_date ?? result.first_air_date ?? ""
        let year = String(raw.prefix(4))
        return year.count == 4 ? year : nil
    }
}
