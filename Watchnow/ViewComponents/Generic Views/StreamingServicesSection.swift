//
//  StreamingServicesSection.swift
//  Watchnow
//
//  "Browse by streaming service" — a horizontal chip bar of streaming
//  services available in the user's region, with the selected chip's
//  catalogue shown directly underneath. Netflix is preselected (or the
//  highest-priority provider in the region if Netflix isn't carried).
//
//  Layout reads as: chip bar (filter) → result row (content). Tapping a
//  chip swaps the result row to that provider's titles in place — no
//  modal, no navigation push. Quick-scan, "find what's on my Netflix"
//  experience without leaving the home feed.
//
//  Source data: TMDB's `/discover/{movie|tv}` endpoint with
//  `with_watch_providers=ID` and `with_watch_monetization_types=flatrate`
//  so only subscription content surfaces (no rentals, no purchases).
//

import SwiftUI
import Kingfisher

struct StreamingServicesSection<VM: BaseContentViewModel>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion


    @ObservedObject var viewModel: VM
    let viewSection: ViewSections

    @Namespace private var namespace

    // Overscroll-to-load-more state, mirrored from the BottomView /
    // TopView pattern. The progress tracker is an ObservableObject
    // (rather than a plain @State CGFloat) so the trailing
    // LoadMoreButtonView can re-render *during* the user's pull —
    // StretchingActionScrollView's parent-update buffering would
    // otherwise freeze the button at progress=0 until release.
    @StateObject private var loadMoreProgress = LoadMoreProgress()
    @State private var thresholdReached: Bool = false
    @State private var performFeedback: Bool = false

    // Incremented every time the active provider changes. Used as the
    // `.id()` on `populatedRow` so SwiftUI treats each provider's scroll
    // view as a distinct identity and plays its `.transition` on swap.
    @State private var cardAnimationToken: Int = 0

    // Fixed dimensions matching the BottomView carousel grammar so the
    // streaming-services row sits in the page at the same scale and
    // rhythm as the other card carousels. Slot is the GeometryReader's
    // outer bound; card is the inner content; the slot/card ratio
    // (~1.25) leaves room for the scale-up at centre screen without
    // the scaled content clipping the slot.
    private let cardWidth:   CGFloat = 110
    private let cardHeight:  CGFloat = 220
    private let slotWidth:   CGFloat = 138
    private let slotHeight:  CGFloat = 275

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                chipBar
                resultsRow
                    // Pinning the result-row height keeps the section's
                    // overall footprint stable across loading / loaded /
                    // empty / error so the page below doesn't shift when
                    // the user taps a different chip.
                    .frame(height: slotHeight)
            }
        } header: {
            SectionHeaderView(
                title: viewSection.cleanTitle,
                subtitle: subtitle,
                icon: viewSection.themeIcon,
                tint: viewSection.themeColor,
                showsPulse: viewSection.isTrending
            )
            .textCase(.none)
        }
        // The result row is pinned to `slotHeight` with a 165pt poster inside
        // it, which leaves the title and meta line a fixed ~55pt to live in.
        // Capped so that budget holds; every tile opens a details screen that
        // scales without a ceiling.
        .artworkTypeClamp()
    }

    /// Section subtitle — surfaces the picked provider's name when we
    /// have one, so the result row's identity is unambiguous even if
    /// the user has scrolled the chip bar past the active selection.
    private var subtitle: String {
        if let name = viewModel.selectedProvider?.provider_name {
            return "Showing what's on \(name)"
        }
        return "Find what's on your subscription"
    }

    // MARK: - Chip bar

    private var chipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.providers ?? []) { provider in
                    Button {
                        Task { await viewModel.selectProvider(provider) }
                    } label: {
                        ProviderChip(
                            provider: provider,
                            isSelected: viewModel.selectedProvider?.id == provider.id
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .sensoryFeedback(.selection, trigger: viewModel.selectedProvider?.id)
        .onChange(of: viewModel.selectedProvider?.id) { _, _ in
            withAnimation(reduceMotion ? nil : .easeInOut(duration: AppMotion.standard)) {
                cardAnimationToken += 1
            }
        }
    }

    // MARK: - Results row

    @ViewBuilder
    private var resultsRow: some View {
        if viewModel.isLoadingProviderResults {
            loadingRow
        } else if viewModel.providerResults.isEmpty {
            emptyRow
        } else {
            populatedRow
        }
    }

    /// Carousel of result thumbs with the same focal-card scale effect
    /// the rest of the home feed uses (BottomView, TopView). Each card
    /// scales up to 1.25× as it crosses the screen centre, settling to
    /// 1.0× at the edges. Wrapped in `StretchingActionScrollView` so
    /// pulling past the trailing edge triggers `loadMoreProviderResults`
    /// — the same overscroll-to-paginate gesture every other carousel uses.
    /// The scroll view is given a stable `.id(cardAnimationToken)` so
    /// SwiftUI treats each provider's row as a distinct view identity.
    /// When the token bumps (inside `withAnimation`) the old row plays
    /// its `.transition` remove and the new row plays its insert — a
    /// single cheap crossfade for the whole surface, with no per-card
    /// state that could re-trigger on scroll.
    private var populatedRow: some View {
        StretchingActionScrollView(
            onTriggered: {
                Task { @MainActor in
                    performFeedback.toggle()
                    await viewModel.loadMoreProviderResults()
                }
            },
            onThresholdReached: { reached in self.thresholdReached = reached },
            onProgress: { progress in self.loadMoreProgress.value = progress },
            content: { populatedRowContent }
        )
        .sensoryFeedback(.success, trigger: performFeedback)
        .id(cardAnimationToken)
        .transition(.opacity)
    }

    private var populatedRowContent: some View {
        let screenHalfWidth = UIScreen.main.bounds.width / 2

        return HStack(alignment: .top, spacing: 0) {
            Spacer().frame(width: 10)
            ForEach(viewModel.providerResults, id: \.self) { result in
                providerCard(for: result, screenHalfWidth: screenHalfWidth)

                if result == viewModel.providerResults.last,
                   viewModel.canLoadMoreProviderResults {
                    LoadMoreButtonView(tracker: loadMoreProgress)
                }
            }
        }
    }

    @ViewBuilder
    private func providerCard(for result: Result, screenHalfWidth: CGFloat) -> some View {
        let link = NavigationLink {
            let model = ContentDetailsModel(screenType: viewModel.screenType, result: result)
            let detailVM = ContentDetailsViewModel(model: model)
            ContentDetailsView(detailsViewModel: detailVM)
                .navigationTransition(.zoom(sourceID: result.id, in: namespace))
        } label: {
            ProviderResultThumb(result: result)
        }
        .matchedTransitionSource(id: result.id, in: namespace)
        .buttonStyle(.plain)

        if #available(iOS 17, *) {
            link
                .frame(width: cardWidth, height: cardHeight)
                .visualEffect { content, geometry in
                    let diff = abs(screenHalfWidth - geometry.frame(in: .global).midX)
                    let threshold: CGFloat = 150
                    let scale = diff < threshold ? 1.0 + (threshold - diff) / 600.0 : 1.0
                    return content.scaleEffect(scale)
                }
                .frame(width: slotWidth, height: slotHeight)
        } else {
            GeometryReader { proxy in
                link
                    .frame(width: cardWidth, height: cardHeight)
                    .scaleEffect(Scale.getScale(proxy: proxy, scaleType: .vertical))
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
            .frame(width: slotWidth, height: slotHeight)
        }
    }

    /// Shimmer placeholders matching the real thumb layout — poster
    /// rectangle + 2 short text lines below. Same height as a populated
    /// row so the section doesn't visually "bounce" while a chip change
    /// resolves.
    private var loadingRow: some View {
        InlineShimmerContainer {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    Spacer().frame(width: 10)
                    ForEach(0..<6, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 6) {
                            ShimmerBox(cornerRadius: AppRadius.card)
                                .frame(width: cardWidth, height: 165)
                            ShimmerBox(cornerRadius: AppRadius.micro)
                                .frame(width: cardWidth * 0.85, height: 11)
                            ShimmerBox(cornerRadius: AppRadius.micro)
                                .frame(width: cardWidth * 0.55, height: 9)
                        }
                    }
                }
                .padding(.vertical, 20)
            }
            .disabled(true)
        }
    }

    private var emptyRow: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "tray")
                    .appFont(24, weight: .light, relativeTo: .title2)
                    .foregroundStyle(.secondary)
                Text("Nothing matching this filter")
                    .appFont(13, relativeTo: .footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

// MARK: - ProviderChip

/// Capsule chip carrying a small provider logo + the service name on a
/// single horizontal line. Selection state flips to a tinted accent fill
/// with white text — same grammar as the genre filter chips on the same
/// screen, so the chip-as-filter language stays consistent.
///
/// On iOS 26+ both states use the system liquid-glass material:
/// `.regular` (frosted) when idle, `.regular.tinted()` (accent-washed
/// glass) when selected. The logo retains its own rounded white square
/// background so it reads clearly against any content behind the glass.
private struct ProviderChip: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion


    let provider: WatchProvider
    let isSelected: Bool

    private let logoSize: CGFloat = 22
    private let logoPadCorner: CGFloat = 5

    var body: some View {
        chipContent
            .scaleEffect(isSelected ? 1.03 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.68), value: isSelected)
    }

    // Same reasoning as GenreChip — glass inside a scroll view re-composites
    // every frame and hurts scroll performance. Solid fill retained.
    private var chipContent: some View {
        HStack(spacing: 8) {
            logo
            Text(provider.provider_name)
                .appFont(13, weight: .semibold, relativeTo: .footnote)
                .foregroundStyle(isSelected ? .white : .primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.leading, 6)
        .padding(.trailing, 14)
        .padding(.vertical, 6)
        .background {
            Capsule(style: .continuous)
                .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(isSelected
                              ? Color.accentColor.opacity(0.45)
                              : Color.primary.opacity(0.08),
                              lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private var logo: some View {
        if let url = provider.logoURL {
            KFImage.url(url)
                .loadImmediately()
                .fromMemoryCacheOrRefresh()
                .cacheOriginalImage()
                .fade(duration: 0.2)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: logoSize, height: logoSize)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: logoPadCorner, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: logoPadCorner, style: .continuous)
                .fill(Color(.tertiarySystemFill))
                .frame(width: logoSize, height: logoSize)
                .overlay {
                    Text(String(provider.provider_name.prefix(1)).uppercased())
                        .appFont(11, weight: .bold, relativeTo: .caption2, design: .rounded)
                        .foregroundStyle(.secondary)
                }
        }
    }
}

// MARK: - ProviderResultThumb

/// Compact poster card used in the inline results row. Smaller than
/// `BottomCard` (110pt vs. 130pt) because the chip bar already takes
/// vertical space, and the goal here is "as many titles visible at once
/// as possible" so the user can scan their subscription quickly.
private struct ProviderResultThumb: View {

    let result: Result

    private let posterWidth:  CGFloat = 110
    private let posterHeight: CGFloat = 165

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            poster

            Text(result.getResultTitle())
                .appFont(12, weight: .semibold, relativeTo: .caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: posterWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            metaRow
                .frame(width: posterWidth, alignment: .leading)
        }
        .frame(width: posterWidth)
    }

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
                    .stroke(.white.opacity(0.08), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
    }

    @ViewBuilder
    private var metaRow: some View {
        let year = result.getReleaseDate(addSeparator: false)
        let rating = (result.vote_average ?? 0) > 0 ? result.vote_average : nil
        let ratingText = rating.map { String(format: "%.1f", $0) }

        if ratingText != nil || !year.isEmpty {
            HStack(spacing: 4) {
                if let ratingText {
                    Image(systemName: "star.fill")
                        .appFont(9, relativeTo: .caption2)
                        .foregroundStyle(RatingStyle.tint(for: rating))
                    Text(ratingText)
                        .appFont(10, weight: .semibold, relativeTo: .caption2)
                        .foregroundStyle(.secondary)
                }
                if ratingText != nil, !year.isEmpty {
                    Text("•").appFont(10, relativeTo: .caption2).foregroundStyle(.secondary.opacity(0.6))
                }
                if !year.isEmpty {
                    Text(year)
                        .appFont(10, weight: .medium, relativeTo: .caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
