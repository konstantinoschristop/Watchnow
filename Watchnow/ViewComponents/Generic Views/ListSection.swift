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

    /// Three items is enough to break the rhythm from the horizontal
    /// carousels above without dwarfing them.
    private let previewCount: Int = 3

    @Namespace private var namespace

    private var visibleResults: [Result] {
        Array(results.prefix(previewCount)).map { result in
            var r = result
            r.media_type = screenType == .movie ? "movie" : "tv"
            return r
        }
    }

    var body: some View {
        Section {
            VStack(spacing: 0) {
                ForEach(Array(visibleResults.enumerated()), id: \.element) { idx, result in
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

                    if idx < visibleResults.count - 1 {
                        Divider()
                            .padding(.leading, 92)   // aligns under the title column
                            .opacity(0.4)
                    }
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
            .loadDiskFileSynchronously()
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
