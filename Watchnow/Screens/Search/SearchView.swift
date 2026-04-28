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
struct SearchView: View {

    @ObservedObject var viewModel: SearchViewModel
    @State private var searchInput = ""
    @FocusState private var searchFieldFocused: Bool
    @Namespace private var namespace

    var body: some View {
        contentView
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
            .searchable(text: $searchInput,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Movies, TV series, actors")
            .onChange(of: searchInput) { _, newValue in
                if newValue.isEmpty {
                    viewModel.clearResults()
                    return
                }
                guard newValue.count > 1 else { return }
                Task {
                    try? await Task.sleep(for: .seconds(0.6))
                    guard newValue == searchInput else { return }
                    await viewModel.getResults(search: newValue)
                }
            }
    }
}

// MARK: - State dispatch

private extension SearchView {

    /// Dispatches to one of five states. Kept flat so the reader sees the
    /// full taxonomy at a glance instead of nested `if`s.
    @ViewBuilder
    var contentView: some View {
        if viewModel.isSearching {
            loadingState
        } else if viewModel.apiError {
            errorState
        } else if let results = viewModel.results {
            if results.isEmpty {
                noResultsState
            } else {
                resultsView(total: results.count)
            }
        } else {
            initialState
        }
    }

    // MARK: Placeholder states

    /// Dimmed full-screen spinner. Shown only while we're waiting on the
    /// network — the previous results stay visible right up until we swap
    /// them out, so the spinner only appears on the first search or after
    /// `clearResults()`.
    var loadingState: some View {
        ProgressView()
            .controlSize(.large)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var errorState: some View {
        ContentUnavailableView {
            themedLabel(title: "Couldn't search",
                        systemImage: "wifi.exclamationmark",
                        tint: .orange)
        } description: {
            Text("Check your connection and try again.")
        }
    }

    var noResultsState: some View {
        ContentUnavailableView.search(text: searchInput)
    }

    /// The screen the user sees before typing anything.
    /// When there are recent searches, shows a "Recent" chip section
    /// instead of the generic placeholder.
    @ViewBuilder
    var initialState: some View {
        if viewModel.recentSearches.isEmpty {
            ContentUnavailableView {
                themedLabel(title: "Find something to watch",
                            systemImage: "magnifyingglass",
                            tint: .accentColor)
            } description: {
                Text("Search across movies, TV series, and actors.")
            }
        } else {
            recentSearchesView
        }
    }

    var recentSearchesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Recent")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button("Clear All") {
                        viewModel.clearRecentSearches()
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                }
                .padding(.horizontal, 16)

                FlowLayout(spacing: 8) {
                    ForEach(viewModel.recentSearches, id: \.self) { query in
                        RecentSearchChip(query: query) {
                            searchInput = query
                        } onRemove: {
                            viewModel.removeRecentSearch(query)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 16)
        }
    }

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
                            namespace: namespace)
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.interactively)
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

    @ViewBuilder
    func resultCountRow(total: Int) -> some View {
        HStack(spacing: 4) {
            Text(resultCountText(total: total))
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
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
                        withAnimation(.easeOut(duration: 0.18)) {
                            viewModel.selectedChooser = option
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
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

// MARK: - RecentSearchChip

private struct RecentSearchChip: View {
    let query: String
    let onTap: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                Text(query)
                    .font(.system(size: 13, weight: .medium))
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(3)
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                Capsule(style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FlowLayout

/// A simple wrapping layout that flows chips into rows.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                height += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
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

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? .white.opacity(0.85) : tint.opacity(0.8))
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
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
