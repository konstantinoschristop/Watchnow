//
//  WatchlistView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 6/8/22.
//

import Foundation
import SwiftUI
import AlertToast

/// User's saved titles. Built around two UX bets:
///
/// 1. **Custom underlined tabs in the nav-bar's principal slot.** The tabs
///    carry per-media tint (Movies = accent, TV Series = purple, matching
///    `MediaTypeBadge`) plus a sliding `matchedGeometryEffect` underline,
///    giving the screen a branded control instead of a stock segmented
///    picker. Placing the tabs in `ToolbarItem(placement: .principal)` was
///    the trick — earlier attempts to pin them under the nav bar via
///    `safeAreaInset(.top)` or as an inline strip fought the List scroll
///    and caused jitter. The principal slot takes the title's own space,
///    so there's nothing for the tabs to compete with and the List flows
///    cleanly from the top.
/// 2. **Two-tier empty states.** Global empty (nothing saved anywhere) vs.
///    per-tab empty (the other tab has items). The per-tab state points the
///    user at the populated tab with a one-tap CTA, so a mis-selected tab
///    never looks like an unrecoverable dead end.
///
/// No in-list search and no pull-to-refresh: the watchlist is a personally
/// curated set (users shouldn't accumulate so many titles that search pays
/// off), and the list updates push-side via `WatchlistManager` on every
/// add/remove plus an `onAppear` pass — so there's nothing for a manual
/// pull gesture to reconcile.
struct WatchlistView: View {

    @ObservedObject var watchlistViewModel: WatchlistViewModel
    @State private var selectedTab: WatchlistModel.Tab = .movies
    @Namespace private var tabNamespace
    @Namespace private var navigationNamespace

    var body: some View {
        content
            .background(Color(.background))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isGlobalEmpty {
                    ToolbarItem(placement: .principal) { filterTabs }
                }
            }
            .onAppear { watchlistViewModel.refreshDataIfNeeded() }
            .toast(isPresenting: $watchlistViewModel.showRemovedAlert) {
                AlertToast(displayMode: .alert,
                           type: .error(.red),
                           title: "Removed from Watchlist")
            }
            .toast(isPresenting: $watchlistViewModel.showAddedAlert) {
                AlertToast(displayMode: .alert,
                           type: .complete(.green),
                           title: "Added to Watchlist")
            }
    }

    // MARK: - Content dispatch

    /// Single switch that drives what fills the screen. Kept flat so the
    /// reader sees every possible state in one place.
    @ViewBuilder
    private var content: some View {
        if isGlobalEmpty {
            globalEmptyState
        } else if currentTabItems.isEmpty {
            tabEmptyState
        } else {
            listView(items: currentTabItems)
        }
    }

    private func listView(items: [Result]) -> some View {
        // `.constant` because the source of truth is the view model's
        // savedMovies / savedSeries arrays; swipe-to-remove mutates those
        // via `viewModel.itemRemoved`, which re-renders this view with a
        // fresh list. Giving the ForEach a direct binding would duplicate
        // state and desync the two.
        List {
            GenericListView(results: .constant(items),
                            viewModel: watchlistViewModel,
                            namespace: navigationNamespace)
        }
        .listStyle(.plain)
    }

    // MARK: - Filter tabs

    /// Two underlined tabs riding in the nav-bar's principal slot. The
    /// active underline is a single `Capsule` shared across both tabs via
    /// `matchedGeometryEffect`, so switching tabs slides it horizontally
    /// instead of cross-fading.
    ///
    /// `minWidth` gives the tabs room to breathe inside the toolbar — the
    /// slot hugs content tightly by default and the labels would render
    /// cramped without an explicit floor.
    private var filterTabs: some View {
        HStack(spacing: 0) {
            ForEach(WatchlistModel.Tab.allCases, id: \.self) { tab in
                UnderlineTab(
                    title: tab.title,
                    count: count(for: tab),
                    isSelected: selectedTab == tab,
                    tint: tint(for: tab),
                    namespace: tabNamespace
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        selectedTab = tab
                    }
                }
            }
        }
        .frame(minWidth: 260)
    }

    private func count(for tab: WatchlistModel.Tab) -> Int {
        switch tab {
        case .movies: return watchlistViewModel.savedMovies.count
        case .series: return watchlistViewModel.savedSeries.count
        }
    }

    /// Category tint — mirrors `MediaTypeBadge` in the row so the empty
    /// state paints in the same colour family the user sees on every row.
    /// The segmented picker itself is left on system chrome; tinting a
    /// segmented control fights the native look.
    private func tint(for tab: WatchlistModel.Tab) -> Color {
        switch tab {
        case .movies: return .accentColor
        case .series: return .purple
        }
    }

    // MARK: - Empty states

    /// Shown when both tabs are empty. Points the user at the bookmark
    /// icon — the actual add surface — instead of the old "swipe right"
    /// wording which never matched reality. Bookmark glyph paints in the
    /// brand accent so the empty state still feels on-theme rather than
    /// grey-on-grey.
    private var globalEmptyState: some View {
        ContentUnavailableView {
            themedLabel(title: "Your Watchlist is empty",
                        systemImage: "bookmark",
                        tint: .accentColor)
        } description: {
            Text("Tap the bookmark on any movie or TV series to save it here.")
        }
    }

    /// Per-tab empty state. Icon + CTA paint in the *selected* tab's tint
    /// (Movies = accent, TV Series = purple), so the empty screen still
    /// reads as "this is the Movies tab" / "this is the Series tab" even
    /// without any rows to ground it.
    private var tabEmptyState: some View {
        let selectedTint = tint(for: selectedTab)
        return ContentUnavailableView {
            themedLabel(title: tabEmptyTitle,
                        systemImage: tabEmptyIcon,
                        tint: selectedTint)
        } description: {
            Text(tabEmptyDescription)
        } actions: {
            if otherTabCount > 0 {
                Button(otherTabActionTitle) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = selectedTab == .movies ? .series : .movies
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(tint(for: selectedTab == .movies ? .series : .movies))
            }
        }
    }

    /// `ContentUnavailableView`'s single-string `Label` initializer can't
    /// tint just the icon — `.foregroundStyle` bleeds into the title. The
    /// two-slot `Label` keeps the colour on the SF Symbol and lets the
    /// title stay primary / legible.
    private func themedLabel(title: String,
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

    // MARK: - Data shaping

    private var currentTabItems: [Result] {
        switch selectedTab {
        case .movies: return watchlistViewModel.savedMovies
        case .series: return watchlistViewModel.savedSeries
        }
    }

    private var isGlobalEmpty: Bool {
        watchlistViewModel.savedMovies.isEmpty && watchlistViewModel.savedSeries.isEmpty
    }

    private var otherTabCount: Int {
        selectedTab == .movies
            ? watchlistViewModel.savedSeries.count
            : watchlistViewModel.savedMovies.count
    }

    // MARK: - Copy

    private var tabEmptyTitle: String {
        switch selectedTab {
        case .movies: return "No saved movies"
        case .series: return "No saved TV series"
        }
    }

    private var tabEmptyIcon: String {
        switch selectedTab {
        case .movies: return "film"
        case .series: return "tv"
        }
    }

    private var tabEmptyDescription: String {
        switch selectedTab {
        case .movies: return "Movies you bookmark will appear here."
        case .series: return "TV series you bookmark will appear here."
        }
    }

    private var otherTabActionTitle: String {
        selectedTab == .movies ? "See TV Series (\(otherTabCount))" : "See Movies (\(otherTabCount))"
    }
}

// MARK: - UnderlineTab

/// Single tab: title + count pill + sliding tinted underline. The
/// underline is driven by the caller's `matchedGeometryEffect` namespace
/// so the active indicator animates between tabs as one continuous shape.
///
/// Each tab carries a `tint` matching the media-type colour grammar
/// (Movies = accent, TV Series = purple, mirroring `MediaTypeBadge`).
/// Tint paints the active underline and the count pill; the title itself
/// stays primary so typography stays quiet and readable. Sized tight
/// (small fonts, minimal vertical padding) because it lives inside the
/// nav-bar's principal slot, where vertical headroom is ~44pt.
private struct UnderlineTab: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let tint: Color
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 5) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? Color.white : .secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background {
                                Capsule().fill(isSelected
                                    ? tint
                                    : Color.secondary.opacity(0.15))
                            }
                    }
                }
                .foregroundStyle(isSelected ? .primary : .secondary)

                // The underline lives in a fixed-height container either way
                // so the row doesn't jump when the tinted capsule slides in.
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(tint)
                            .frame(height: 2)
                            .matchedGeometryEffect(id: "watchlist-tab-underline",
                                                   in: namespace)
                    } else {
                        Color.clear.frame(height: 2)
                    }
                }
                .padding(.horizontal, 10)
            }
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
