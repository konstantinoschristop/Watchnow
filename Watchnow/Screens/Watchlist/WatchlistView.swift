//
//  WatchlistView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 6/8/22.
//

import Foundation
import SwiftUI
import AlertToast

/// User's saved titles. Three tabs: Movies, Series, and Watched.
///
/// - Movies + Series tabs support sort order (Date Added / A→Z / Rating)
///   via a toolbar menu.
/// - Watched tab is a reverse-chronological log; swipe left removes a title
///   from the watched list.
struct WatchlistView: View {

    @ObservedObject var watchlistViewModel: WatchlistViewModel
    @State private var selectedTab: WatchlistModel.Tab = .movies
    @Namespace private var tabNamespace
    @Namespace private var navigationNamespace

    var body: some View {
        VStack(spacing: 0) {
            if !isGlobalEmpty {
                tabBar
            }
            content
        }
        .background(Color(.background))
        .navigationBarTitleDisplayMode(.inline)
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
        .toast(isPresenting: $watchlistViewModel.showWatchedRemovedAlert) {
            AlertToast(displayMode: .alert,
                       type: .complete(.green),
                       title: "Removed from Watched")
        }
    }

    // MARK: - Tab bar (tabs + sort button in one row)

    private var tabBar: some View {
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
                .frame(maxWidth: .infinity)
            }

            // Sort button — always in the layout so tabs never shift.
            // Invisible on the Watched tab (no sort applicable there).
            let sortVisible = selectedTab != .watched && !currentTabItems.isEmpty
            sortMenuButton
                .padding(.horizontal, 14)
                .opacity(sortVisible ? 1 : 0)
                .disabled(!sortVisible)
        }
        .padding(.vertical, 4)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - Content dispatch

    @ViewBuilder
    private var content: some View {
        if isGlobalEmpty {
            globalEmptyState
        } else if selectedTab == .watched {
            if watchlistViewModel.savedWatched.isEmpty {
                tabEmptyState
            } else {
                watchedListView
            }
        } else if currentTabItems.isEmpty {
            tabEmptyState
        } else {
            watchlistListView(items: currentTabItems)
        }
    }

    private func watchlistListView(items: [Result]) -> some View {
        List {
            GenericListView(results: .constant(items),
                            viewModel: watchlistViewModel,
                            namespace: navigationNamespace)
        }
        .listStyle(.plain)
    }

    private var watchedListView: some View {
        List {
            ForEach(watchlistViewModel.savedWatched, id: \.self) { result in
                NavigationLink {
                    let model = ContentDetailsModel(screenType: result.media_type == "movie" ? .movie : .tv,
                                                   result: result)
                    let vm = ContentDetailsViewModel(model: model)
                    ContentDetailsView(detailsViewModel: vm)
                        .navigationTransition(.zoom(sourceID: result.id, in: navigationNamespace))
                } label: {
                    ResultRow(result: result)
                }
                .matchedTransitionSource(id: result.id, in: navigationNamespace)
                .listRowBackground(Color(.background))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        watchlistViewModel.watchedItemRemoved(result: result)
                    } label: {
                        Label("Remove", systemImage: "xmark.circle")
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Sort menu

    private var sortMenuButton: some View {
        Menu {
            ForEach(WatchlistModel.SortOrder.allCases) { order in
                Button {
                    watchlistViewModel.setSortOrder(order)
                } label: {
                    Label(order.rawValue, systemImage: order.icon)
                    if watchlistViewModel.sortOrder == order {
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .symbolVariant(watchlistViewModel.sortOrder == .dateAdded ? .none : .fill)
        }
    }

    private func count(for tab: WatchlistModel.Tab) -> Int {
        switch tab {
        case .movies:  return watchlistViewModel.savedMovies.count
        case .series:  return watchlistViewModel.savedSeries.count
        case .watched: return watchlistViewModel.savedWatched.count
        }
    }

    /// All tabs share the accent palette — the underline + tinted count
    /// pill is the only thing that draws the eye, so per-tab colours just
    /// add visual noise. Watched still gets the brand green ONLY when it's
    /// the selected tab, because that's the one place "completion" semantics
    /// add real meaning to the colour.
    private func tint(for tab: WatchlistModel.Tab) -> Color {
        switch tab {
        case .watched: return .green
        default:       return .accentColor
        }
    }

    // MARK: - Empty states

    private var globalEmptyState: some View {
        ContentUnavailableView {
            themedLabel(title: "Your Watchlist is empty",
                        systemImage: "bookmark",
                        tint: .accentColor)
        } description: {
            Text("Tap the bookmark on any movie or TV series to save it here.")
        }
    }

    @ViewBuilder
    private var tabEmptyState: some View {
        let selectedTint = tint(for: selectedTab)
        ContentUnavailableView {
            themedLabel(title: tabEmptyTitle,
                        systemImage: tabEmptyIcon,
                        tint: selectedTint)
        } description: {
            Text(tabEmptyDescription)
        } actions: {
            if let cta = tabEmptyCTA {
                Button(cta.title) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = cta.destination
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(tint(for: cta.destination))
            }
        }
    }

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
        case .movies:  return watchlistViewModel.savedMovies
        case .series:  return watchlistViewModel.savedSeries
        case .watched: return watchlistViewModel.savedWatched
        }
    }

    private var isGlobalEmpty: Bool {
        watchlistViewModel.savedMovies.isEmpty
            && watchlistViewModel.savedSeries.isEmpty
            && watchlistViewModel.savedWatched.isEmpty
    }

    // MARK: - Copy

    private var tabEmptyTitle: String {
        switch selectedTab {
        case .movies:  return "No saved movies"
        case .series:  return "No saved series"
        case .watched: return "Nothing watched yet"
        }
    }

    private var tabEmptyIcon: String {
        switch selectedTab {
        case .movies:  return "film"
        case .series:  return "tv"
        case .watched: return "checkmark.circle"
        }
    }

    private var tabEmptyDescription: String {
        switch selectedTab {
        case .movies:  return "Movies you bookmark will appear here."
        case .series:  return "TV series you bookmark will appear here."
        case .watched: return "Mark a title as watched from its detail page."
        }
    }

    /// Returns a CTA that points to the first non-empty other tab, or nil when all are empty.
    private var tabEmptyCTA: (title: String, destination: WatchlistModel.Tab)? {
        let others = WatchlistModel.Tab.allCases.filter { $0 != selectedTab && count(for: $0) > 0 }
        guard let dest = others.first else { return nil }
        let n = count(for: dest)
        return ("See \(dest.title) (\(n))", dest)
    }
}

// MARK: - UnderlineTab

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
                        .font(.system(size: 16, weight: .semibold))
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
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
