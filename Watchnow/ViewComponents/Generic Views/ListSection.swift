//
//  ListSection.swift
//  Watchnow
//
//  Vertical "scroll payoff" section for the bottom of each main feed.
//  A dedicated `ListSectionRow` replaces the shared `ResultRow` so the
//  row can drop the redundant media-type badge ("MOVIE" in the Movies
//  tab is just noise) and surface info that actually helps the user
//  skim — genres + release year + rating chip.
//

import SwiftUI
import Kingfisher

struct ListSection<VM: BaseViewModelProtocol>: View {

    let results:     [Result]
    let screenType:  ScreenTypes
    let viewSection: ViewSections
    let viewModel:   VM

    /// Three rich rows per page; up to three pages (9 titles) the user can
    /// swipe through horizontally. Three keeps each page from dwarfing the
    /// poster carousels above, while paging lets the section surface far more
    /// of the list than a single static trio.
    private let pageSize: Int = 3
    private let maxItems: Int = 9

    @Namespace private var namespace

    /// Page index currently snapped to the leading edge of the pager, driven
    /// two-way by `.scrollPosition` so the dots track swipes *and* dot taps
    /// scroll the pager. `nil` only before the first layout pass.
    @State private var pageID: Int? = 0
    private var currentPage: Int { pageID ?? 0 }

    private var visibleResults: [Result] {
        Array(results.prefix(maxItems)).map { result in
            var r = result
            r.media_type = screenType == .movie ? "movie" : "tv"
            return r
        }
    }

    /// `visibleResults` split into pages of `pageSize` (the last page may be
    /// short when fewer than `maxItems` titles came back).
    private var pages: [[Result]] {
        stride(from: 0, to: visibleResults.count, by: pageSize).map { start in
            Array(visibleResults[start ..< min(start + pageSize, visibleResults.count)])
        }
    }

    var body: some View {
        Section {
            VStack(spacing: 12) {
                pager
                if pages.count > 1 {
                    pageDots
                }
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

    // MARK: - Pager

    /// Page-snapping horizontal scroll view. A non-lazy `HStack` measures
    /// every page up front, which pins the section's height to the tallest
    /// page — so the feed below it doesn't jump as the user swipes between
    /// pages whose rows wrap to different heights.
    private var pager: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, pageItems in
                    pageColumn(pageItems)
                        .containerRelativeFrame(.horizontal)
                        .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $pageID)
        .scrollIndicators(.hidden)
    }

    /// One page: up to three rows, divided like the original static list.
    private func pageColumn(_ items: [Result]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element) { idx, result in
                row(result)
                if idx < items.count - 1 {
                    Divider()
                        .padding(.leading, 92)   // aligns under the title column
                        .opacity(0.4)
                }
            }
        }
    }

    private func row(_ result: Result) -> some View {
        NavigationLink {
            let model = ContentDetailsModel(screenType: screenType, result: result)
            let vm = ContentDetailsViewModel(model: model)
            ContentDetailsView(detailsViewModel: vm)
                .navigationTransition(.zoom(sourceID: result.id, in: namespace))
        } label: {
            ListSectionRow(result: result)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
        }
        .matchedTransitionSource(id: result.id, in: namespace)
        .buttonStyle(.plain)
    }

    // MARK: - Page indicator

    /// Pill-style dots: the active page stretches into a short capsule in the
    /// section tint. Tapping a dot scrolls to that page.
    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(pages.indices, id: \.self) { i in
                Capsule(style: .continuous)
                    .fill(i == currentPage ? viewSection.themeColor
                                           : Color.secondary.opacity(0.3))
                    .frame(width: i == currentPage ? 16 : 6, height: 6)
                    .contentShape(Capsule())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            pageID = i
                        }
                    }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentPage)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - ListSectionRow

/// Row shape: poster on the left, text column in the middle, rating chip
/// pinned to the trailing edge. No media-type badge — the tab already tells
/// the user they're looking at movies or series.
private struct ListSectionRow: View {

    let result: Result

    private let posterWidth:  CGFloat = 64
    private let posterHeight: CGFloat = 96
    private let posterRadius: CGFloat = 10

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            poster
            textColumn
            Spacer(minLength: 8)
            trailingColumn
        }
    }

    // MARK: Poster

    private var poster: some View {
        KFImage.url(result.getResultPosterURL())
            .downsampling(size: CGSize(width: 256, height: 384))
            .loadImmediately()
            .fromMemoryCacheOrRefresh()
            .cacheOriginalImage()
            .fade(duration: 0.2)
            .placeholder {
                RoundedRectangle(cornerRadius: posterRadius, style: .continuous)
                    .fill(Color.secondary.opacity(0.15))
                    .overlay {
                        Image(systemName: "film")
                            .font(.system(size: 20, weight: .light))
                            .foregroundStyle(.secondary)
                    }
            }
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: posterWidth, height: posterHeight)
            .clipShape(RoundedRectangle(cornerRadius: posterRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: posterRadius, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
    }

    // MARK: Text column (title + genres + overview)

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(result.getResultTitle())
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if !genrePills.isEmpty {
                HStack(spacing: 5) {
                    ForEach(genrePills, id: \.self) { name in
                        Text(name)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .overlay {
                                Capsule().strokeBorder(.secondary.opacity(0.35),
                                                       lineWidth: 0.5)
                            }
                    }
                }
            }

            if let overview = overviewSnippet {
                Text(overview)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: Trailing column (rating chip + year)

    /// Prominent rating chip pinned to the right, with the release year
    /// directly below. Keeps the year available at a glance while giving
    /// the rating visual weight that matches its importance to the user.
    @ViewBuilder
    private var trailingColumn: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if let rating {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(String(format: "%.1f", rating))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundStyle(RatingStyle.tint(for: rating))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    Capsule().fill(RatingStyle.tint(for: rating).opacity(0.15))
                }
                .overlay {
                    Capsule().strokeBorder(RatingStyle.tint(for: rating).opacity(0.35),
                                           lineWidth: 0.5)
                }
            }

            if let year = yearString {
                Text(year)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Helpers

    private var rating: Double? {
        guard let rating = result.vote_average, rating > 0 else { return nil }
        return rating
    }

    private var yearString: String? {
        let raw = result.getReleaseDate(addSeparator: false)
        return raw.isEmpty ? nil : raw
    }

    private var overviewSnippet: String? {
        guard let overview = result.overview,
              !overview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return overview
    }

    /// Up to 2 genre names from `genre_ids`, using the shared TMDB lookup.
    /// Two is plenty — any more and the row's middle column starts
    /// competing with the title for attention.
    private var genrePills: [String] {
        guard let ids = result.genre_ids else { return [] }
        return ids.prefix(2).compactMap { tmdbGenreNames[$0] }
    }
}
