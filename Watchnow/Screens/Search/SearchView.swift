//
//  SearchView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 10/7/22.
//

import SwiftUI
import AlertToast

/// Top-level search screen.
///
/// The screen reads top-to-bottom as: search field → filter chips → result
/// count → list. The older segmented picker was pinned to the bottom safe
/// area, which made the filter feel disconnected from the content it
/// filtered and sat right under the thumb where mis-taps were easy. The
/// chip bar keeps the filter in reading order and leaves the bottom of the
/// screen clear for content.
///
/// This view owns the *state machine* (initial / loading / error / empty /
/// results) and the query pipeline. The pre-typing screen itself lives in
/// `SearchStartView`.
struct SearchView: View {

    @ObservedObject var viewModel: SearchViewModel
    @FocusState private var searchFieldFocused: Bool
    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The in-flight query task. Held so a new keystroke can cancel the
    /// previous one — the old code started a fresh detached `Task` per
    /// character and let each sleep out its debounce before discarding
    /// itself, which meant a ten-letter query queued ten tasks.
    @State private var searchTask: Task<Void, Never>?
    /// The query most recently handed to the view model. Lets a tap on a
    /// recent chip fire immediately *and* keeps the resulting
    /// `viewModel.query` change from scheduling a duplicate debounced fetch.
    @State private var dispatchedQuery = ""
    /// Whether the user has asked for search. Set by the hero's chip, cleared
    /// by Cancel. Distinct from "has a query" so tapping the chip brings the
    /// field and keyboard up over an empty start screen.
    @State private var searchActive = false

    /// Debounce window for typed input. Short enough to feel live, long
    /// enough that a normal typing cadence doesn't spend a request per
    /// character.
    private let debounce: Duration = .seconds(0.45)

    var body: some View {
        VStack(spacing: 0) {
            if searchBarVisible {
                SearchFieldBar(text: $viewModel.query,
                               isFocused: $searchFieldFocused,
                               onCancel: cancelSearch)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            contentView
        }
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.88),
                   value: searchBarVisible)
        // No navigation bar on this tab at all. The title said "Search" on
        // the search tab, and the bar's only other job was carrying the
        // system search field, which `SearchFieldBar` has replaced.
        .toolbar(.hidden, for: .navigationBar)
        .toast(isPresenting: $viewModel.showAddedAlert) {
            AlertToast(displayMode: .alert,
                       type: .complete(.green),
                       title: "Added to Watchlist")
        }
        .toast(isPresenting: $viewModel.showRemovedAlert) {
            AlertToast(displayMode: .alert,
                       type: .error(.red),
                       title: "Removed from Watchlist")
        }
        // The bar has to exist before it can take focus, so arming search
        // renders it first and this hands it the keyboard on the next pass.
        .task(id: searchActive) {
            if searchActive { searchFieldFocused = true }
        }
        .onChange(of: viewModel.query) { _, newValue in
            queryChanged(to: newValue)
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    /// The bar is up from the moment search is armed until it is cancelled.
    /// Results keep it up on their own so dismissing the keyboard never
    /// strands the user with results and no field to edit.
    private var searchBarVisible: Bool {
        searchActive || !viewModel.query.isEmpty || viewModel.results != nil
    }
}

// MARK: - Query pipeline

private extension SearchView {

    /// Single entry point for every change to the text field, whether the
    /// user typed it or a recent chip filled it in.
    func queryChanged(to newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            searchTask?.cancel()
            dispatchedQuery = ""
            viewModel.clearResults()
            return
        }

        // A chip tap already kicked this exact query off immediately; the
        // resulting text-field change lands here a beat later and must not
        // queue a second, identical request.
        guard trimmed != dispatchedQuery else { return }

        // Deleting back down to a single character has to cancel whatever
        // is pending, not just decline to start something new — otherwise
        // the two-character query the user just backspaced away still
        // lands, and the list fills with results for text that is no
        // longer in the field.
        guard trimmed.count > 1 else {
            searchTask?.cancel()
            return
        }

        runSearch(trimmed, immediate: false)
    }

    /// Cancels any pending query and schedules a new one. `immediate`
    /// skips the debounce for explicit, complete queries (a recent-search
    /// chip), where waiting out the typing window would just read as lag.
    func runSearch(_ query: String, immediate: Bool) {
        searchTask?.cancel()
        dispatchedQuery = query

        searchTask = Task {
            if !immediate {
                try? await Task.sleep(for: debounce)
                guard !Task.isCancelled else { return }
            }
            await viewModel.getResults(search: query)
        }
    }

    /// Runs a genre browse. Reuses `searchTask` so a browse and a typed
    /// query can't both be in flight — whichever the user asked for last
    /// wins, same as two consecutive queries.
    func browseGenre(_ genre: SearchModel.Genre) {
        searchTask?.cancel()
        dispatchedQuery = ""
        searchFieldFocused = false
        searchTask = Task {
            await viewModel.browse(genre: genre)
        }
    }

    /// Full reset back to the start screen.
    func cancelSearch() {
        searchTask?.cancel()
        dispatchedQuery = ""
        viewModel.query = ""
        viewModel.clearResults()
        searchFieldFocused = false
        searchActive = false
    }
}

// MARK: - SearchChromeModifier

// MARK: - State dispatch

private extension SearchView {

    /// The five mutually exclusive screens this view can show. Modelled
    /// explicitly so the cross-fade below has a single `Equatable` value to
    /// animate on — `.animation(_:value:)` needs one, and deriving it from
    /// the `if` chain is what keeps the two in sync.
    enum Phase: Equatable {
        case initial, loading, error, empty, results
    }

    var phase: Phase {
        if viewModel.isSearching { return .loading }
        if viewModel.apiError { return .error }
        guard let results = viewModel.results else { return .initial }
        return results.isEmpty ? .empty : .results
    }

    /// Dispatches to one of five states. Kept flat so the reader sees the
    /// full taxonomy at a glance instead of nested `if`s. The branches
    /// cross-fade rather than snap — previously a search swapped the whole
    /// screen between frames, which read as a flicker.
    @ViewBuilder
    var contentView: some View {
        Group {
            switch phase {
            case .loading:
                SearchResultsSkeleton()
                    .transition(.opacity)
            case .error:
                errorState
                    .transition(.opacity)
            case .empty:
                noResultsState
                    .transition(.opacity)
            case .results:
                resultsView(total: viewModel.results?.count ?? 0)
                    .transition(.opacity)
            case .initial:
                initialState
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: AppMotion.standard), value: phase)
    }

    // MARK: Placeholder states

    var errorState: some View {
        ContentUnavailableView {
            themedLabel(title: "Couldn't search",
                        systemImage: "wifi.exclamationmark",
                        tint: .orange)
        } description: {
            Text("Check your connection and try again.")
        } actions: {
            Button("Try Again") {
                if let genre = viewModel.activeGenre {
                    browseGenre(genre)
                } else if !dispatchedQuery.isEmpty {
                    runSearch(dispatchedQuery, immediate: true)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(.accentColor)
        }
    }

    @ViewBuilder
    var noResultsState: some View {
        if let genre = viewModel.activeGenre {
            // `ContentUnavailableView.search(text:)` renders "No Results for
            // \"…\"" around the search string, which is empty on a genre
            // browse — so this path gets its own copy rather than an empty
            // pair of quotes.
            ContentUnavailableView {
                themedLabel(title: "No \(genre.name.lowercased()) titles",
                            systemImage: genre.symbol,
                            tint: .accentColor)
            } description: {
                Text("Nothing came back for this genre. Try another one.")
            }
        } else {
            ContentUnavailableView.search(text: viewModel.query)
        }
    }

    /// The screen the user sees before typing anything — recents plus a
    /// live trending shelf. See `SearchStartView`.
    var initialState: some View {
        SearchStartView(viewModel: viewModel,
                        bleedsUnderStatusBar: heroOwnsTopEdge,
                        isSearchFieldFocused: searchFieldFocused,
                        onActivateSearch: { searchActive = true },
                        onSelectQuery: { query in
                            viewModel.query = query
                            runSearch(query, immediate: true)
                            searchFieldFocused = false
                        },
                        onSelectGenre: { genre in
                            browseGenre(genre)
                        })
    }

    /// Whether the start screen's art reaches the top of the display.
    /// Tracks exactly when `SearchChromeModifier` hides the navigation bar,
    /// so the hero's extra height and its status-bar scrim only appear on
    /// the platform where there's actually a bar missing.
    var heroOwnsTopEdge: Bool { true }

    /// Shared empty-state label builder. `ContentUnavailableView`'s
    /// single-string `Label` initializer can't tint just the icon —
    /// `.foregroundStyle` would bleed into the title. The two-slot `Label`
    /// keeps the colour on the SF Symbol and lets the title stay primary.
    func themedLabel(title: String,
                     systemImage: String,
                     tint: Color) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
        }
    }
}

// MARK: - Results

private extension SearchView {

    /// Results layout: filter chips up top, count caption, then the list.
    /// The chip bar + count live outside the `List` so they don't scroll
    /// with the results — filtering is an always-available control, not
    /// a row that gets pushed off-screen.
    func resultsView(total: Int) -> some View {
        VStack(spacing: 0) {
            filterChipBar
                .padding(.top, 8)
                .padding(.bottom, 6)

            resultCountRow(total: total)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)

            Divider().opacity(0.4)

            if viewModel.filteredResults.isEmpty {
                filterEmptyState
            } else {
                resultsList
            }
        }
    }

    var resultsList: some View {
        List {
            GenericListView(results: $viewModel.filteredResults,
                            viewModel: viewModel,
                            namespace: namespace,
                            adSlot: 4)

            if viewModel.activeGenre != nil, viewModel.genreHasMore {
                loadMoreRow
            }

            // A simple banner block at the foot of the list — same treatment
            // as the bottom of the home/details scroll pages.
            InlineBannerSection()
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.interactively)
    }

    /// Footer for a genre browse. A typed search doesn't get one — TMDB's
    /// multi endpoint puts the matches worth showing on page one, whereas a
    /// genre is a shelf the user is browsing and forty titles is the start
    /// of it, not the end.
    ///
    /// An explicit button rather than infinite scroll: the row sits above an
    /// ad block, and a list that grows on its own would keep pushing that
    /// out of reach while the user is still reading.
    var loadMoreRow: some View {
        Button {
            Task { await viewModel.loadMoreGenreResults() }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isLoadingMoreGenre {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.down.circle")
                        .font(.footnote.weight(.semibold))
                }
                Text(viewModel.isLoadingMoreGenre ? "Loading…" : "Show more")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoadingMoreGenre)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .accessibilityLabel("Show more results")
    }

    /// Shown when the server returned results but the active filter
    /// excludes them all. Kept distinct from `noResultsState` so the user
    /// can tell "nothing exists" from "you're filtering it away". Icon +
    /// CTA paint in the *selected* chooser's tint so the empty state still
    /// grounds the user in which filter is active.
    var filterEmptyState: some View {
        let chipTint = tint(for: viewModel.selectedChooser)
        return ContentUnavailableView {
            themedLabel(title: "No \(viewModel.selectedChooser.getTitle().lowercased())",
                        systemImage: "line.3.horizontal.decrease.circle",
                        tint: chipTint)
        } description: {
            Text("No matches for this filter. Try another category.")
        } actions: {
            Button("Show All") { viewModel.selectedChooser = .all }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.accentColor)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: Result count

    /// Count caption, prefixed with the genre when the list came from a
    /// chip rather than a typed query — without it the results read as a
    /// search for nothing, since the field is empty on that path.
    @ViewBuilder
    func resultCountRow(total: Int) -> some View {
        HStack(spacing: 6) {
            if let genre = viewModel.activeGenre {
                Label(genre.name, systemImage: genre.symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityLabel("Browsing \(genre.name)")

                Text("·")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            Text(resultCountText(total: total))
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .easeOut(duration: AppMotion.quick),
                           value: viewModel.filteredResults.count)
            Spacer(minLength: 0)
        }
    }

    func resultCountText(total: Int) -> String {
        let filtered = viewModel.filteredResults.count
        if viewModel.selectedChooser == .all {
            return "\(total) result\(total == 1 ? "" : "s")"
        }
        return "\(filtered) of \(total) \(total == 1 ? "result" : "results")"
    }
}

// MARK: - Filter chips

private extension SearchView {

    /// Horizontal scroll of pill buttons. Scroll-capable so the row stays
    /// legible on the smallest screens without truncating titles; on a
    /// Pro-sized device all four chips fit comfortably without scrolling.
    var filterChipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchModel.SearchChooserOptions.allCases, id: \.self) { option in
                    FilterChip(
                        title: option.getTitle(),
                        count: count(for: option),
                        isSelected: viewModel.selectedChooser == option,
                        tint: tint(for: option)
                    ) {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: AppMotion.quick)) {
                            viewModel.selectedChooser = option
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .sensoryFeedback(.selection, trigger: viewModel.selectedChooser)
    }

    /// Per-chip badge count. Drives the little "(12)" next to the title so
    /// the user knows whether flipping to a filter will actually surface
    /// anything. `.all` is always the total, which reads as the whole set.
    func count(for option: SearchModel.SearchChooserOptions) -> Int {
        guard let results = viewModel.results else { return 0 }
        if option == .all { return results.count }
        return results.filter { $0.getMediaType() == option.rawValue }.count
    }

    /// Single accent palette for all chips. The four-colour scheme used to
    /// pair with `MediaTypeBadge` tints, but with the badge muted to
    /// secondary text the tint now lives only in the *selected* state —
    /// which is the only state that needs to draw the eye anyway.
    func tint(for option: SearchModel.SearchChooserOptions) -> Color {
        .accentColor
    }
}

// MARK: - SearchResultsSkeleton

/// Shimmer stand-in for the results list, shaped like `ResultRow`.
///
/// Replaces a centred `ProgressView`. A bare spinner on a full-screen
/// surface gives no hint about what's coming and reads as "the app is
/// thinking"; a skeleton in the shape of the answer reads as "the answer
/// is loading" and keeps the eye where the results will land.
private struct SearchResultsSkeleton: View {

    /// Matches `ResultRow`'s poster box exactly so rows don't shift when
    /// the real content swaps in.
    private let posterWidth: CGFloat = 64
    private let posterHeight: CGFloat = 96

    var body: some View {
        InlineShimmerContainer {
            VStack(spacing: 0) {
                // Filter chip bar placeholder.
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { index in
                        ShimmerBox(cornerRadius: AppRadius.hero)
                            .frame(width: CGFloat(52 + (index % 3) * 22), height: 30)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)

                ForEach(0..<6, id: \.self) { _ in
                    row
                }

                Spacer(minLength: 0)
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel("Searching")
    }

    private var row: some View {
        HStack(alignment: .top, spacing: 12) {
            ShimmerBox(cornerRadius: AppRadius.card)
                .frame(width: posterWidth, height: posterHeight)

            VStack(alignment: .leading, spacing: 7) {
                ShimmerBox(cornerRadius: AppRadius.micro).frame(width: 54, height: 14)
                ShimmerBox(cornerRadius: AppRadius.micro).frame(width: 180, height: 15)
                ShimmerBox(cornerRadius: AppRadius.micro).frame(width: 110, height: 11)
                ShimmerBox(cornerRadius: AppRadius.micro).frame(maxWidth: .infinity).frame(height: 10)
                ShimmerBox(cornerRadius: AppRadius.micro).frame(width: 200, height: 10)
                Spacer(minLength: 0)
            }
            .frame(height: posterHeight, alignment: .top)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - FilterChip

/// Single filter pill. Carries a category tint (passed in by the caller)
/// that mirrors the matching row's `MediaTypeBadge`, so the chip a user
/// picks up top paints with the same colour as the badge they'll see on
/// every matching row below. Unselected chips show the tint quietly as
/// label + hairline border; the selected chip flips to a solid tint fill
/// with white text. Count is hidden when zero so empty categories still
/// read as tappable without a misleading "(0)".
private struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let tint: Color
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .appFont(13, weight: .semibold, relativeTo: .footnote)
                if count > 0 {
                    Text("\(count)")
                        .appFont(12, weight: .semibold, relativeTo: .caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.85) : tint.opacity(0.8))
                        .contentTransition(.numericText())
                }
            }
            .foregroundStyle(isSelected ? .white : tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                Capsule(style: .continuous)
                    .fill(isSelected ? tint : tint.opacity(0.12))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : tint.opacity(0.35),
                                  lineWidth: 0.5)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.68),
                   value: isSelected)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
