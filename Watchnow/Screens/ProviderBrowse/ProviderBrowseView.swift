//
//  ProviderBrowseView.swift
//  Watchnow
//
//  "See all" for the Browse by Streaming row: one service's whole
//  subscription catalogue, and a search scoped to it.
//
//  Reads top to bottom as: a hero card in the service's colours, cycling
//  through what's biggest on it right now → a filter bar that pins under the
//  navigation bar (search, sort, Movies / Series, genres) → the Top 10 →
//  everything else as a grid that keeps loading as it scrolls.
//
//  Motion: the hero drifts and crossfades between titles, a pill slides
//  under whichever filter is on, and a new filter deals its posters in as a
//  cascade. All of it stops under Reduce Motion — the screen reads the same
//  without it.
//

import SwiftUI
import Kingfisher

struct ProviderBrowseView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @StateObject private var viewModel: ProviderBrowseViewModel

    /// The tapped poster, pushed as a details screen.
    @State private var selection: ZoomSource?
    /// Matches each poster to the details screen it opens, for the zoom.
    @Namespace private var namespace
    /// The selection pills slide between chips rather than blinking.
    @Namespace private var pills

    @State private var scrollPosition = ScrollPosition(edge: .top)
    /// Height of everything above the filter bar, so a new filter can bring
    /// the user back to the top of the grid rather than the top of the page.
    @State private var heroBlockHeight: CGFloat = 0
    /// True once the hero has scrolled away and the filter bar is pinned:
    /// the bar takes a background and the navigation bar takes the title.
    @State private var isCollapsed = false
    /// Drives the grid's entrance cascade — the first load only. Replaying
    /// it on every filter tap made a small change feel like a page reload.
    @State private var gridRevealed = false
    @FocusState private var searchFocused: Bool
    /// The search field's text. Owned here and handed to the field as a
    /// binding, but never read in this body: the field forwards each change
    /// to the view model itself, so a keystroke re-renders the field, not
    /// the screen.
    @State private var searchQuery = ""

    /// Flexible columns between these widths: three across an iPhone in
    /// portrait, more wherever there's room.
    private let columns = [
        GridItem(.adaptive(minimum: 104, maximum: 170), spacing: 12, alignment: .top)
    ]

    init(providers: [WatchProvider],
         provider: WatchProvider,
         screenType: ScreenTypes,
         region: String) {
        _viewModel = StateObject(wrappedValue: ProviderBrowseViewModel(providers: providers,
                                                                       provider: provider,
                                                                       screenType: screenType,
                                                                       region: region))
    }


    /// The service's colours, by role — see `ProviderBrand`. Fills take
    /// `brand` with `onBrand` on top; text and icons on the page take `tint`;
    /// shadows and the ambient wash take `glow`.
    private var brand: Color { ProviderBrand.color(for: viewModel.provider.provider_id) }
    private var onBrand: Color { ProviderBrand.foreground(for: viewModel.provider.provider_id) }
    private var tint: Color { ProviderBrand.tint(for: viewModel.provider.provider_id) }
    private var glow: Color { ProviderBrand.glow(for: viewModel.provider.provider_id) }
    private var providerName: String { viewModel.provider.provider_name }

    var body: some View {
        // Measured out here, where the safe area still applies: the page runs
        // up under the status and navigation bars, like the feed's and the
        // details screen's, and a reader inside that scope sees no inset.
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    hero
                        // The filter bar opens with a spacer the height of the
                        // bars, which it needs once it pins under them. Until
                        // then the spacer lies over the hero's foot instead of
                        // pushing the bar down.
                        .padding(.bottom, -topInset)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { heroBlockHeight = $0 }

                    Section {
                        content(minSearchHeight: proxy.size.height)
                    } header: {
                        filterBar(topInset: topInset)
                    }
                }
            }
            .scrollPosition($scrollPosition)
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            // Collapsed the moment the filter bar pins under the bars, and
            // not before. Collapsing 24pt early put the bar's material on
            // while it was still sliding up through the hero, leaving a strip
            // of bare art above a frosted band. Not until the hero has been
            // measured, either: against a height of zero, the page would
            // open collapsed.
            .onScrollGeometryChange(for: Bool.self) { geometry in
                heroBlockHeight > 0
                    && geometry.contentOffset.y + geometry.contentInsets.top >= heroBlockHeight - 0.5
            } action: { _, collapsed in
                withAnimation(reduceMotion ? nil : .easeInOut(duration: AppMotion.standard)) {
                    isCollapsed = collapsed
                }
            }
            .ignoresSafeArea(edges: .top)
            // The hero shades the bars itself, and once it's gone the pinned
            // filter bar's material does. The soft edge effect on top of
            // either only frosts what's already legible.
            .modifier(TopScrollEdgeEffectHidden(hidden: true))
        }
        .background { ambientGlow }
        // The hero shows through the bars; once it's gone, the pinned filter
        // bar's own material runs up behind them instead.
        .toolbarBackground(.hidden, for: .navigationBar)
        // Status bar and back button sit on the hero's dark art until the
        // filter bar pins; set light until then, as on the feed and details.
        .toolbarColorScheme(isCollapsed ? nil : .dark, for: .navigationBar)
        .navigationTitle(providerName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                collapsedTitle
                    .opacity(isCollapsed ? 1 : 0)
                    .offset(y: isCollapsed || reduceMotion ? 0 : 8)
                    .allowsHitTesting(isCollapsed)
                    .accessibilityHidden(!isCollapsed)
            }
        }
        .navigationDestination(item: $selection) { source in
            let result = source.result
            let screenType = ScreenTypes(rawValue: result.media_type ?? "") ?? viewModel.query.screenType
            ContentDetailsView(detailsViewModel: ContentDetailsViewModel(
                model: ContentDetailsModel(screenType: screenType, result: result)))
                .navigationTransition(.zoom(sourceID: source, in: namespace))
        }
        .onChange(of: viewModel.query) { _, _ in
            // A new filter is a new list. Deep in the old one, land at the
            // top of the new one, with the filters still pinned above it.
            if isCollapsed { scrollPosition.scrollTo(y: heroBlockHeight) }
        }
        .onChange(of: searchFocused) { _, focused in
            // Searching takes the screen: the field rides up to the top, on
            // the keyboard's own timing rather than a spring racing it.
            guard focused, !isCollapsed else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: AppMotion.standard)) {
                scrollPosition.scrollTo(y: heroBlockHeight)
            }
        }
        // Results start at their top, just under the pinned field — when the
        // search begins and each time a new query's results land. Left where
        // it was, a search begun deep in the catalogue kept that depth, and
        // the shorter results came up already scrolled past their first rows.
        .onChange(of: viewModel.isSearching) { _, searching in
            if searching { scrollPosition.scrollTo(y: heroBlockHeight) }
        }
        .onChange(of: viewModel.searchResults?.query) { _, query in
            if query != nil { scrollPosition.scrollTo(y: heroBlockHeight) }
        }
        .sensoryFeedback(.selection, trigger: viewModel.query)
        .task { viewModel.loadIfNeeded() }
        // Covers in a fixed number of columns, like every other poster grid;
        // each opens a details screen that scales without a ceiling.
        .artworkTypeClamp()
    }

    // MARK: - Hero

    /// The same hero as the Movies and Series tabs — the service's leading
    /// titles, full bleed, with the same copy, actions and dots — so the two
    /// headers read as one design. The service sits in the badge, where a
    /// tap switches to another.
    @ViewBuilder
    private var hero: some View {
        if viewModel.heroTitles.isEmpty {
            // Holds the hero's place until its titles land, so the page
            // below doesn't jump when they do.
            LinearGradient(colors: [glow.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom)
                .containerRelativeFrame(.vertical) { height, _ in
                    height * FeaturedHeroMetrics.heightFraction
                }
        } else {
            MenuFeaturedView(results: viewModel.heroTitles,
                             overlayContent: { result in
                                 HeroSlideCopy(result: result, screenType: viewModel.heroScreenType) {
                                     serviceKicker
                                 }
                             },
                             screenType: viewModel.heroScreenType,
                             // `ambientGlow`'s base; the glow itself is
                             // spent before the hero's foot.
                             pageColor: Color(.systemBackground))
                // Another service, or Movies and Series switched: a new set
                // of titles starts the slideshow over from the first.
                .id(viewModel.heroTitles.compactMap(\.id))
        }
    }

    /// The service's logo and name, in the kicker's type, opening the same
    /// switcher as the collapsed title.
    private var serviceKicker: some View {
        Menu {
            providerPicker
        } label: {
            HStack(spacing: 7) {
                ProviderLogo(provider: viewModel.provider, size: 18)
                Text(verbatim: providerName.uppercased(with: .current))
                    .heroKickerStyle()
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .appFont(9, weight: .bold, relativeTo: .caption2)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .heroBadge(leading: 5)
            .contentShape(Capsule())
        }
        .accessibilityLabel(Text(providerName))
    }

    // MARK: - Chrome

    /// The service's colour washing down from the top of the screen. Sits
    /// behind the scroll view, so it stays put while the content moves and
    /// tints the pinned filter bar's material once it's there.
    private var ambientGlow: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground)
            RadialGradient(colors: [glow.opacity(0.34), glow.opacity(0.10), .clear],
                           center: .top,
                           startRadius: 10,
                           endRadius: 480)
                .frame(height: 600)
        }
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .easeInOut(duration: AppMotion.slow), value: viewModel.provider)
    }

    /// The navigation bar's title once the hero has gone: the service, and
    /// the same switcher the hero's name opens.
    private var collapsedTitle: some View {
        Menu {
            providerPicker
        } label: {
            HStack(spacing: 7) {
                ProviderLogo(provider: viewModel.provider, size: 22)
                Text(providerName)
                    .appFont(16, weight: .bold, relativeTo: .headline)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .appFont(10, weight: .bold, relativeTo: .caption2)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
        }
    }

    private var providerPicker: some View {
        ProviderPicker(provider: viewModel.provider, providers: viewModel.providers) {
            viewModel.select(provider: $0)
        }
    }

    // MARK: - Filter bar

    /// Search mode begins the moment the field is focused, not at the first
    /// keystroke: the filters fold away together with the keyboard rising,
    /// instead of the header jumping under the user's first letter.
    private var inSearchMode: Bool { searchFocused || viewModel.isSearching }

    private func filterBar(topInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Clears the status and navigation bars once the bar pins. Lies
            // over the hero's foot until then — see the hero's bottom padding.
            Color.clear
                .frame(height: topInset)
                .allowsHitTesting(false)

            filterControls
        }
        .background(alignment: .bottom) {
            // Nothing while it sits in the page under the hero. Once it
            // pins, one surface from the top of the screen down, so the grid
            // never slides through the gap between the bars and the filters.
            // Added and removed rather than faded to zero: a material at zero
            // opacity still blurs what's behind it, every frame.
            if isCollapsed {
                Rectangle()
                    .fill(.bar)
                    .overlay(alignment: .bottom) { Divider().opacity(0.6) }
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
    }

    private var filterControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                ProviderSearchField(text: $searchQuery,
                                    isFocused: $searchFocused,
                                    placeholder: String(localized: "Search in \(providerName)",
                                                        comment: "Placeholder: search inside one streaming service; the service's name"),
                                    isLoading: viewModel.isSearchLoading,
                                    tint: tint,
                                    glow: glow,
                                    onChange: { viewModel.updateSearch($0) })

                if inSearchMode {
                    Button("Cancel") {
                        searchQuery = ""
                        searchFocused = false
                    }
                    .appFont(16, relativeTo: .body)
                    .tint(tint)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    sortMenu
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)

            if !inSearchMode {
                filterChips
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
        .animation(reduceMotion ? nil : .easeOut(duration: AppMotion.standard), value: inSearchMode)
    }

    private var sortMenu: some View {
        Menu {
            Picker(String(localized: "Sort"),
                   selection: Binding(get: { viewModel.query.sort },
                                      set: { viewModel.select(sort: $0) })) {
                ForEach(ProviderBrowseSort.allCases) { sort in
                    Label(sort.title, systemImage: sort.symbol).tag(sort)
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.up.arrow.down")
                    .imageScale(.small)
                    .symbolEffect(.bounce, value: viewModel.query.sort)
                Text(viewModel.query.sort.title)
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }
            .appFont(13, weight: .bold, relativeTo: .footnote)
            .foregroundStyle(tint)
            .padding(.horizontal, 13)
            .frame(height: 42)
            .background(Capsule().fill(Color(.tertiarySystemFill)))
            .contentShape(Capsule())
        }
        .accessibilityLabel(Text("Sort"))
        .accessibilityValue(Text(viewModel.query.sort.title))
    }

    /// Movies / Series first, then the genres, on one strip. "All" clears
    /// the genre; so does tapping the genre that's on.
    private var filterChips: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    typeToggle

                    Capsule()
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 1, height: 22)
                        .padding(.horizontal, 2)

                    genreChip(String(localized: "All", comment: "Genre filter chip that clears the filter"),
                              isSelected: viewModel.query.genreID == nil) {
                        viewModel.select(genreID: nil)
                    }
                    .id(-1)

                    ForEach(viewModel.genreIDs, id: \.self) { genreID in
                        genreChip(GenreNames.shared.name(for: genreID) ?? "",
                                  isSelected: viewModel.query.genreID == genreID) {
                            viewModel.select(genreID: viewModel.query.genreID == genreID ? nil : genreID)
                        }
                        .id(genreID)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
            }
            // Only the chips animate on a tap — the pill sliding to its new
            // place. Wrapping the whole state change in a spring used to
            // bounce the page below as the grid reloaded under it.
            .animation(reduceMotion ? nil : AppMotion.springSnappy, value: viewModel.query)
            // Movies and Series have different genre lists. When switching
            // keeps a genre, bring its chip back into view.
            .onChange(of: viewModel.query.screenType) { _, _ in
                withAnimation(reduceMotion ? nil : .easeInOut(duration: AppMotion.standard)) {
                    proxy.scrollTo(viewModel.query.genreID ?? -1, anchor: .center)
                }
            }
        }
    }

    private var typeToggle: some View {
        HStack(spacing: 0) {
            typeSegment(.movie, title: "Movies")
            typeSegment(.tv, title: "Series")
        }
        .padding(3)
        .background(Capsule().fill(Color(.tertiarySystemFill)))
    }

    private func typeSegment(_ type: ScreenTypes, title: LocalizedStringKey) -> some View {
        let isOn = viewModel.query.screenType == type
        return Button {
            viewModel.select(screenType: type)
        } label: {
            // A mode, not a filter, so it slides a neutral thumb like a
            // segmented control. The brand colour stays with the genre — two
            // brand pills side by side read as two filters.
            Text(title)
                .appFont(13, weight: .bold, relativeTo: .footnote)
                .foregroundStyle(isOn ? .primary : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background {
                    if isOn {
                        Capsule()
                            .fill(Color(.secondarySystemGroupedBackground))
                            .shadow(color: .black.opacity(0.14), radius: 4, y: 1)
                            .matchedGeometryEffect(id: "type", in: pills)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func genreChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .appFont(13, weight: .semibold, relativeTo: .footnote)
                .foregroundStyle(isSelected ? onBrand : Color.primary.opacity(0.75))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(brand)
                            .shadow(color: glow.opacity(0.4), radius: 6, y: 2)
                            .matchedGeometryEffect(id: "genre", in: pills)
                    } else {
                        Capsule()
                            .fill(Color(.tertiarySystemFill))
                            .overlay { Capsule().strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5) }
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Content

    /// `minSearchHeight`: the screen's height. Search content is never less,
    /// so the page can always scroll far enough to pin the field with the
    /// results under it. A handful of results is shorter than the screen,
    /// and the scroll view would otherwise settle lower, pulling the field
    /// back down off the top.
    private func content(minSearchHeight: CGFloat) -> some View {
        ZStack(alignment: .top) {
            if viewModel.isSearching {
                searchContent
                    .frame(maxWidth: .infinity, minHeight: minSearchHeight, alignment: .topLeading)
                    .transition(.opacity)
            } else {
                catalogue
                    .overlay {
                        // Focused but empty: the catalogue stays, dimmed, as
                        // the system search does — and a tap on it puts the
                        // keyboard away.
                        if searchFocused {
                            Rectangle()
                                .fill(Color(.systemBackground).opacity(0.7))
                                .onTapGesture { searchFocused = false }
                                .transition(.opacity)
                        }
                    }
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: AppMotion.standard), value: viewModel.isSearching)
        .animation(reduceMotion ? nil : .easeOut(duration: AppMotion.quick), value: searchFocused)
    }

    private var catalogue: some View {
        Group {
            switch viewModel.phase {
            case .loading:
                loadingGrid
                    .transition(.opacity)
            case .failed:
                failedState
                    .transition(.opacity)
            case .empty:
                emptyState
                    .transition(.opacity)
            case .loaded:
                loadedCatalogue
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: AppMotion.standard), value: viewModel.phase)
    }

    /// The Top 10 leads only the unfiltered, most-popular view — under a
    /// genre or another sort, "top 10" would mean something else. Judged on
    /// the query the titles on screen came from, so it doesn't vanish from
    /// above them while the next filter's titles are on their way.
    private var showsTopTen: Bool {
        let shown = viewModel.resultsQuery
        return shown.sort == .popular && shown.genreID == nil && viewModel.results.count >= 10
    }

    private var loadedCatalogue: some View {
        let leading = showsTopTen ? 10 : 0
        return VStack(alignment: .leading, spacing: 28) {
            if showsTopTen {
                topTen(Array(viewModel.results.prefix(10)))
            }

            VStack(alignment: .leading, spacing: 14) {
                gridHeading

                LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                    ForEach(Array(viewModel.results.dropFirst(leading).enumerated()), id: \.element) { offset, result in
                        posterButton(result, place: .grid)
                            .modifier(CascadeIn(isRevealed: gridRevealed, order: offset, isEnabled: !reduceMotion))
                            .modifier(RiseOnScroll(isEnabled: !reduceMotion))
                            .onAppear { viewModel.loadMoreIfNeeded(at: leading + offset) }
                    }
                }
                .padding(.horizontal, 16)

                if viewModel.canLoadMore {
                    ProgressView()
                        .tint(tint)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        // Catches the case the cells can't: a page short
                        // enough that the bottom is already on screen.
                        .onAppear { viewModel.loadMore() }
                }
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 32)
        .overlay(alignment: .top) {
            // A new filter's titles on their way: the old ones dim under a
            // veil, untappable, until the new ones replace them.
            if viewModel.isRefreshing {
                Rectangle()
                    .fill(Color(.systemBackground).opacity(0.6))
                    .overlay(alignment: .top) {
                        ProgressView()
                            .tint(tint)
                            .padding(.top, 80)
                    }
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: AppMotion.quick), value: viewModel.isRefreshing)
        .onAppear {
            // A beat after insertion, so the cells exist in their hidden
            // state for the cascade to start from.
            Task { @MainActor in gridRevealed = true }
        }
    }

    private func topTen(_ titles: [Result]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeading(icon: "flame.fill",
                           title: String(localized: "Top 10 on \(providerName)",
                                         comment: "Section title: the ten most popular titles on a streaming service; the service's name"))

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .bottom, spacing: 10) {
                    ForEach(Array(titles.enumerated()), id: \.element) { index, result in
                        let source = ZoomSource(result: result, place: .topTen)
                        Button {
                            selection = source
                        } label: {
                            RankedPoster(rank: index + 1, result: result, tint: tint)
                        }
                        .buttonStyle(CarouselPressStyle())
                        .matchedTransitionSource(id: source, in: namespace)
                        .accessibilityLabel(Text("Number \(index + 1), \(result.getResultTitle())"))
                        .modifier(CascadeIn(isRevealed: gridRevealed, order: index, isEnabled: !reduceMotion))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
        }
    }

    /// "Everything on Netflix", or the genre's name once one is picked — and
    /// how many titles that is.
    private var gridHeading: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(viewModel.resultsQuery.genreID.flatMap { GenreNames.shared.name(for: $0) }
                 ?? String(localized: "Everything on \(providerName)",
                           comment: "Section title: a streaming service's whole catalogue; the service's name"))
                .appFont(20, weight: .heavy, relativeTo: .title3)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)

            if let total = viewModel.totalResults {
                Text("\(total) titles")
                    .appFont(12, weight: .bold, relativeTo: .caption)
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(tint.opacity(0.14)))
                    .contentTransition(.numericText(value: Double(total)))
            }
        }
        .padding(.horizontal, 16)
    }

    private func sectionHeading(icon: String, title: String, iconTint: Color? = nil) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .appFont(16, weight: .bold, relativeTo: .headline)
                .foregroundStyle(iconTint ?? tint)
                .symbolRenderingMode(.hierarchical)
            Text(title)
                .appFont(20, weight: .heavy, relativeTo: .title3)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func posterButton(_ result: Result, place: ZoomSource.Place, onService: Bool = false) -> some View {
        let source = ZoomSource(result: result, place: place)
        return Button {
            selection = source
        } label: {
            PosterCell(result: result, seal: brand, sealMark: onBrand, showsOnServiceBadge: onService)
        }
        .buttonStyle(CarouselPressStyle())
        .matchedTransitionSource(id: source, in: namespace)
    }

    // MARK: Catalogue states

    /// Placeholder cells in the real cell's shape — poster, then two short
    /// lines — so the grid doesn't jump when the first page lands.
    private var loadingGrid: some View {
        InlineShimmerContainer {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                ForEach(0..<12, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 7) {
                        ShimmerBox(cornerRadius: AppRadius.panel)
                            .aspectRatio(2/3, contentMode: .fit)
                        ShimmerBox(cornerRadius: AppRadius.micro)
                            .frame(height: 11)
                            .padding(.trailing, 14)
                        ShimmerBox(cornerRadius: AppRadius.micro)
                            .frame(width: 48, height: 9)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 54)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Loading…"))
    }

    private var failedState: some View {
        ContentUnavailableView {
            Label("Couldn't load content", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Check your connection and try again.")
        } actions: {
            Button { viewModel.reload() } label: {
                Text("Retry").foregroundStyle(onBrand)
            }
            .buttonStyle(.borderedProminent)
            .tint(brand)
        }
        .padding(.top, 60)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label {
                Text("Nothing here on \(providerName)",
                     comment: "Streaming service catalogue empty state; the service's name")
            } icon: {
                Image(systemName: "sparkles.tv")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
            }
        } description: {
            Text("Nothing on this service matches these filters in your region.")
        } actions: {
            if viewModel.query.genreID != nil {
                Button { viewModel.select(genreID: nil) } label: {
                    Text("Show All Genres").foregroundStyle(onBrand)
                }
                .buttonStyle(.borderedProminent)
                .tint(brand)
            }
        }
        .padding(.top, 60)
    }

    // MARK: - Search

    @ViewBuilder
    private var searchContent: some View {
        if viewModel.searchFailed {
            ContentUnavailableView {
                Label("Couldn't search", systemImage: "wifi.exclamationmark")
            } description: {
                Text("Check your connection and try again.")
            } actions: {
                Button { viewModel.scheduleSearch(debounce: false) } label: {
                    Text("Try Again").foregroundStyle(onBrand)
                }
                .buttonStyle(.borderedProminent)
                .tint(brand)
            }
            .padding(.top, 40)
        } else if let results = viewModel.searchResults {
            if results.isEmpty {
                ContentUnavailableView.search(text: results.query)
                    .padding(.top, 40)
            } else {
                searchResults(results)
            }
        } else {
            searchSkeleton
        }
    }

    /// What the service has first, as posters with its badge; then what it
    /// doesn't, as quieter rows naming where each one streams instead.
    private func searchResults(_ results: ProviderSearchResults) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            if !results.onService.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    sectionHeading(icon: "checkmark.seal.fill",
                                   title: String(localized: "On \(providerName)",
                                                 comment: "Search section: matches a streaming service carries; the service's name"))
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                        ForEach(results.onService, id: \.self) { result in
                            posterButton(result, place: .search, onService: true)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            if !results.elsewhere.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeading(icon: "xmark.seal",
                                   title: String(localized: "Not on \(providerName)",
                                                 comment: "Search section: matches a streaming service doesn't carry; the service's name"),
                                   iconTint: .secondary)
                    VStack(spacing: 0) {
                        ForEach(results.elsewhere) { entry in
                            let source = ZoomSource(result: entry.result, place: .search)
                            Button {
                                selection = source
                            } label: {
                                ElsewhereRow(entry: entry)
                            }
                            .buttonStyle(.plain)
                            .matchedTransitionSource(id: source, in: namespace)

                            if entry.id != results.elsewhere.last?.id {
                                Divider().padding(.leading, 74)
                            }
                        }
                    }
                    .background {
                        RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous)
                            .fill(Color(.secondarySystemBackground).opacity(0.85))
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 32)
    }

    private var searchSkeleton: some View {
        InlineShimmerContainer {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                ForEach(0..<6, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 7) {
                        ShimmerBox(cornerRadius: AppRadius.panel)
                            .aspectRatio(2/3, contentMode: .fit)
                        ShimmerBox(cornerRadius: AppRadius.micro)
                            .frame(height: 11)
                            .padding(.trailing, 14)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 54)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Loading…"))
    }
}

// MARK: - ZoomSource

/// One poster's identity for the zoom transition. The same title can be on
/// screen twice — in the Top 10 and a search, say — and a zoom given two
/// sources with one id picks either, so the id carries where it was tapped.
struct ZoomSource: Hashable {
    enum Place: Hashable { case topTen, grid, search }

    let result: Result
    let place: Place
}

// MARK: - ProviderPicker

/// The region's services, with a checkmark on the one showing.
private struct ProviderPicker: View {
    let provider: WatchProvider
    let providers: [WatchProvider]
    let onSelect: (WatchProvider) -> Void

    var body: some View {
        Picker(String(localized: "Streaming Service", comment: "Menu title: switch which streaming service's catalogue is shown"),
               selection: Binding(get: { provider }, set: onSelect)) {
            ForEach(providers) { provider in
                Text(provider.provider_name).tag(provider)
            }
        }
    }
}

// MARK: - ProviderSearchField

/// The search field, as a view of its own so a keystroke re-renders the
/// field and nothing else. Its text lives in the parent's `@State`, so
/// Cancel can clear it, but the parent never reads it: changes go straight
/// to `onChange`.
private struct ProviderSearchField: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let placeholder: String
    let isLoading: Bool
    let tint: Color
    let glow: Color
    let onChange: (String) -> Void

    private var focused: Bool { isFocused.wrappedValue }

    var body: some View {
        HStack(spacing: 8) {
            // A search in flight shows where the magnifying glass is. It
            // used to take the clear button's place, which then vanished
            // and came back with every keystroke.
            ZStack {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(tint)
                } else {
                    Image(systemName: "magnifyingglass")
                        .appFont(15, weight: .semibold, relativeTo: .subheadline)
                        .foregroundStyle(focused ? tint : .secondary)
                }
            }
            .frame(width: 18)

            TextField(placeholder, text: $text)
                .appFont(16, relativeTo: .body)
                .focused(isFocused)
                // Results arrive as the user types, so Return only has the
                // keyboard left to put away.
                .submitLabel(.search)
                .onSubmit { isFocused.wrappedValue = false }
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear"))
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(Capsule().fill(Color(.tertiarySystemFill)))
        .overlay {
            Capsule()
                .strokeBorder(focused ? tint.opacity(0.75) : Color.primary.opacity(0.06),
                              lineWidth: focused ? 1.5 : 0.5)
        }
        .shadow(color: focused ? glow.opacity(0.28) : .clear, radius: 12)
        .contentShape(Capsule())
        .onTapGesture { isFocused.wrappedValue = true }
        .animation(reduceMotion ? nil : .easeInOut(duration: AppMotion.quick), value: focused)
        .onChange(of: text) { _, new in onChange(new) }
    }
}

// MARK: - RankedPoster

/// A Top 10 entry: a tall numeral in the service's colour with the poster
/// overlapping it.
private struct RankedPoster: View {
    let rank: Int
    let result: Result
    /// The page tint, not the fill: the numerals sit on the page, and a navy
    /// brand's would vanish on a dark one.
    let tint: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: -10) {
            Text(verbatim: String(rank))
                .font(.system(size: 112, weight: .black, design: .rounded))
                .kerning(-8)
                .foregroundStyle(LinearGradient(colors: [tint, tint.opacity(0.18)],
                                                startPoint: .top,
                                                endPoint: .bottom))
                .fixedSize()
                .offset(y: 18)
                .accessibilityHidden(true)

            PosterArt(result: result)
                .frame(width: 112)
        }
    }
}

// MARK: - PosterCell

/// One poster in a grid: cover with its rating on it, then the title and
/// year. The cover takes the column's width at 2:3, so the grid reflows to
/// however many columns fit.
private struct PosterCell: View {
    let result: Result
    /// The service's fill and the mark on it, for the seal on search matches
    /// it carries.
    let seal: Color
    let sealMark: Color
    var showsOnServiceBadge = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            PosterArt(result: result)
                .overlay(alignment: .topTrailing) { ratingBadge.padding(6) }
                .overlay(alignment: .topLeading) {
                    if showsOnServiceBadge {
                        Image(systemName: "checkmark.seal.fill")
                            .appFont(18, weight: .semibold, relativeTo: .body)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(sealMark, seal)
                            .shadow(color: .black.opacity(0.4), radius: 3)
                            .padding(6)
                    }
                }

            Text(result.getResultTitle())
                .appFont(13, weight: .semibold, relativeTo: .footnote)
                .foregroundStyle(.primary)
                // Two lines held open even for a one-line title, so a row of
                // cells lines up on its year.
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)

            let year = result.getReleaseDate(addSeparator: false)
            if !year.isEmpty {
                Text(year)
                    .appFont(11, weight: .medium, relativeTo: .caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// Solid rather than a material: dozens of these scroll at once, and a
    /// blur behind each is an offscreen pass per cell per frame.
    @ViewBuilder
    private var ratingBadge: some View {
        if let rating = result.vote_average, rating > 0 {
            HStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .appFont(8, weight: .bold, relativeTo: .caption2)
                    .foregroundStyle(RatingStyle.tint(for: rating))
                Text(rating.ratingText)
                    .appFont(10, weight: .bold, relativeTo: .caption2)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(.black.opacity(0.62)))
        }
    }
}

/// A poster at 2:3, sized by a clear box with the image laid over it: an
/// unloaded `KFImage` reports no size of its own, which would collapse the
/// cell until the art arrives.
private struct PosterArt: View {
    let result: Result
    var cornerRadius: CGFloat = AppRadius.panel

    var body: some View {
        Color.clear
            .aspectRatio(2/3, contentMode: .fit)
            .overlay {
                KFImage.url(URL(string: API.Common.imageUrl(imageId: result.poster_path ?? "", width: .poster)))
                    .loadImmediately()
                    .fromMemoryCacheOrRefresh()
                    .cacheOriginalImage()
                    .backgroundDecode()
                    .fade(duration: 0.25)
                    .placeholder {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.15))
                            .overlay {
                                Image(systemName: "film")
                                    .appFont(22, weight: .light, relativeTo: .title2)
                                    .foregroundStyle(.secondary)
                            }
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
            }
            .accessibilityHidden(true)
    }
}

// MARK: - ElsewhereRow

/// A search match the service doesn't carry: dimmed art, and where it's
/// streaming instead — or that nothing in the region streams it.
private struct ElsewhereRow: View {
    let entry: ProviderSearchResults.Elsewhere

    var body: some View {
        HStack(spacing: 12) {
            PosterArt(result: entry.result, cornerRadius: AppRadius.small)
                .frame(width: 46)
                .saturation(0.45)
                .opacity(0.85)

            VStack(alignment: .leading, spacing: 5) {
                Text(entry.result.getResultTitle())
                    .appFont(15, weight: .semibold, relativeTo: .subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let service = entry.streamingOn {
                        ProviderLogo(provider: service, size: 16)
                        Text("Streaming on \(service.provider_name)",
                             comment: "Search row: a title's on another streaming service; the service's name")
                    } else {
                        Image(systemName: "tv.slash")
                        Text("Not streaming in your region")
                    }
                }
                .appFont(12, weight: .medium, relativeTo: .caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .appFont(12, weight: .semibold, relativeTo: .caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - ProviderLogo

/// A service's logo on its own white tile, or its initial when TMDB has no
/// artwork for it. Also the feed's "Explore all" banner's.
struct ProviderLogo: View {
    let provider: WatchProvider
    let size: CGFloat

    var body: some View {
        Group {
            if let url = provider.logoURL {
                KFImage.url(url)
                    .loadImmediately()
                    .fromMemoryCacheOrRefresh()
                    .cacheOriginalImage()
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .background(Color.white)
            } else {
                Color(.tertiarySystemFill)
                    .overlay {
                        Text(String(provider.provider_name.prefix(1)).uppercased())
                            .appFont(size * 0.5, weight: .bold, relativeTo: .caption2, design: .rounded)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .accessibilityHidden(true)
    }
}

// MARK: - Motion

/// The first screenful of a new list arriving one poster after another:
/// each rises and settles a beat after the one before. Only the first dozen
/// cascade — everything below arrives by scrolling, under `RiseOnScroll`.
private struct CascadeIn: ViewModifier {
    let isRevealed: Bool
    let order: Int
    let isEnabled: Bool

    func body(content: Content) -> some View {
        let hidden = isEnabled && order < 12 && !isRevealed
        content
            .opacity(hidden ? 0 : 1)
            .offset(y: hidden ? 28 : 0)
            .scaleEffect(hidden ? 0.92 : 1, anchor: .bottom)
            .animation(isEnabled && order < 12
                       ? .spring(response: 0.5, dampingFraction: 0.78).delay(Double(order) * 0.045)
                       : nil,
                       value: isRevealed)
    }
}

/// Posters coming up from the bottom edge grow into place.
///
/// Transform-only — scale and offset, no opacity. Fading a cell fades a
/// group (poster, title, badge), which renders it offscreen, and with a
/// screenful of cells crossing the edge that was a dozen offscreen passes a
/// frame while scrolling.
private struct RiseOnScroll: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .scrollTransition(topLeading: .identity,
                                  bottomTrailing: .interactive,
                                  axis: .vertical) { view, phase in
                    view
                        .scaleEffect(1 - phase.value * 0.1, anchor: .top)
                        .offset(y: phase.value * 26)
                }
        } else {
            content
        }
    }
}
