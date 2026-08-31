//
//  ContentView.swift
//  Watchnow
//
//  Created by k.christopoulos on 31/7/21.
//

import SwiftUI

struct ContentView: View {

    @StateObject private var moviesViewModel = MoviesViewModel(model: MoviesModel())
    @StateObject private var seriesViewModel = SeriesViewModel(model: SeriesModel())
    @StateObject private var searchViewModel = SearchViewModel(model: SearchModel())
    @StateObject private var watchlistViewModel = WatchlistViewModel(model: WatchlistModel())
    @StateObject private var router = DeepLinkRouter.shared
    /// Shared (like the router) so the DEBUG test bench can drive the same
    /// instance this view presents from.
    @ObservedObject private var whatsNew = WhatsNewViewModel.shared
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab: AppTab = .movies
    @State private var moviesDeepLinkResult: Result?
    @State private var seriesDeepLinkResult: Result?
    #if DEBUG
    @State private var whatsNewDebugPresented = false
    #endif

    /// Opens straight into Movie Night when the app is launched with
    /// `-MovieNightDemo` (e.g. `simctl launch … --args -MovieNightDemo`).
    /// Inert without the argument, so it never affects a normal launch.
    @State private var movieNightDemo = CommandLine.arguments.contains("-MovieNightDemo")

    enum AppTab: Hashable {
        case movies, series, search, watchlist
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Movies", systemImage: "film", value: AppTab.movies) {
                moviesTabContent
            }
            Tab("Series", systemImage: "tv.inset.filled", value: AppTab.series) {
                seriesTabContent
            }
            Tab("Search", systemImage: "magnifyingglass.circle", value: AppTab.search, role: .search) {
                searchTabContent
            }
            Tab("Watchlist", systemImage: "list.bullet.circle.fill", value: AppTab.watchlist) {
                watchlistTabContent
            }
        }
        .onChange(of: router.pending) { _, pending in
            applyDeepLink(pending)
        }
        .fullScreenCover(isPresented: $movieNightDemo) {
            MovieNightView()
        }
        // "While You Were Away": evaluated on launch and on each return to
        // the foreground. The view model owns every decision — this view
        // just hosts the sheet.
        .sheet(isPresented: $whatsNew.isPresented, onDismiss: { whatsNew.briefingDismissed() }) {
            WhatsNewView(vm: whatsNew)
        }
        .task {
            await whatsNew.checkOnLaunch()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await whatsNew.checkOnLaunch() }
            }
        }
    }

    // MARK: - Deeplink handling

    private func applyDeepLink(_ deeplink: DeepLink?) {
        guard let deeplink else { return }
        switch deeplink.mediaType {
        case .movie:
            selectedTab = .movies
            moviesDeepLinkResult = Result.stub(id: deeplink.id, mediaType: "movie")
        case .tv:
            selectedTab = .series
            seriesDeepLinkResult = Result.stub(id: deeplink.id, mediaType: "tv")
        }
        // Consume — clear the router so the same deeplink doesn't re-fire
        // on a subsequent state change.
        router.pending = nil
    }
}

extension ContentView {
    
    private var moviesTabContent: some View {
        NavigationStack {
            MoviesView(moviesViewModel: moviesViewModel)
                .background(Color(.background))
                .navigationTitle("Movies")
                .navigationDestination(item: $moviesDeepLinkResult) { result in
                    detailsDestination(for: result, screenType: .movie)
                }
        }
        .modifier(SoftScrollEdgeEffectStyleModifier())
    }

    private var seriesTabContent: some View {
        NavigationStack {
            SeriesView(seriesViewModel: seriesViewModel)
                .background(Color(.background))
                .navigationTitle("Series")
                .navigationDestination(item: $seriesDeepLinkResult) { result in
                    detailsDestination(for: result, screenType: .tv)
                }
        }
        .modifier(SoftScrollEdgeEffectStyleModifier())
    }

    @ViewBuilder
    private func detailsDestination(for result: Result, screenType: ScreenTypes) -> some View {
        let model = ContentDetailsModel(screenType: screenType, result: result)
        let vm = ContentDetailsViewModel(model: model)
        ContentDetailsView(detailsViewModel: vm)
    }

    private var searchTabContent: some View {
        NavigationStack {
            SearchView(viewModel: searchViewModel)
                .background(Color(.background))
                .navigationTitle("Search")
        }
        .searchPresentationToolbarBehavior(.avoidHidingContent)
        .modifier(SoftScrollEdgeEffectStyleModifier())
    }

    private var watchlistTabContent: some View {
        NavigationStack {
            WatchlistView(watchlistViewModel: watchlistViewModel)
                .background(Color(.background))
                .navigationTitle("Watchlist")
            #if DEBUG
                // Dev-only test bench for the What's New briefing; the
                // whole affordance compiles away in Release.
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            whatsNewDebugPresented = true
                        } label: {
                            Image(systemName: "hammer.circle")
                        }
                        .accessibilityLabel("What's New Testing")
                    }
                }
                .sheet(isPresented: $whatsNewDebugPresented) {
                    WhatsNewDebugView()
                }
            #endif
        }
        .modifier(SoftScrollEdgeEffectStyleModifier())
    }
}
