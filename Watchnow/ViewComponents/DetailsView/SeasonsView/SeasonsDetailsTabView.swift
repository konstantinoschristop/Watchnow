//
//  SeasonsDetailsTabView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 15/8/22.
//

import SwiftUI

struct SeasonsDetailsTabView: View {
    
    @StateObject private var episodesViewModel: EpisodesViewModel
    let seasons: [Season]
    var items: [ScrollableTabBarItemViewModel<Season>] = []
    @Binding var selectedSeason: Season
    @State var showLoader = false
    
    init(seasons: [Season],
         selectedSeason: Binding<Season>,
         seriesID: Int) {
        
        self.seasons = seasons
        _selectedSeason = selectedSeason
        _episodesViewModel = StateObject(wrappedValue: EpisodesViewModel.init(service: ServiceInvocation(),
                                                                              seriesID: seriesID))
        items = seasons.compactMap({ season in
            guard let seasonName = season.name else {
                return nil
            }
            return ScrollableTabBarItemViewModel(id: season,
                                                 title: seasonName)
        })
    }
    
    var body: some View {
        VStack {
            ScrollableTabBarView(items: items,
                                 selectedTab: $selectedSeason)
            .padding(.top)
            
            if showLoader {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .onAppear(perform: {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            showLoader = false
                        }
                    })
            } else if episodesViewModel.episodes?.air_date != nil {
                let episodes = episodesViewModel.episodes?.episodes ?? []
                ScrollView {
                    ForEach(episodes, id: \.self) { episode in
                        EpisodeView(episode: episode)
                    }
                }
            } else {
                Text("This season hasn't started yet!")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .background(Color(.systemGray6))
        .task {
            await episodesViewModel.getEpisodes(seasonNumber: selectedSeason.season_number ?? 0)
        }
        .onChange(of: selectedSeason) { newValue in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                Task {
                    showLoader = true
                    await episodesViewModel.getEpisodes(seasonNumber: selectedSeason.season_number ?? 0)
                }
            }
        }
    }
}

class ScrollableTabBarItemViewModel<IdentifierType: Hashable>: ObservableObject, Hashable, Identifiable {
    var id: IdentifierType
    @Published var title: String

    init(id: IdentifierType,
         title: String) {
        self.id = id
        self.title = title
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ScrollableTabBarItemViewModel, rhs: ScrollableTabBarItemViewModel) -> Bool {
        lhs.id == rhs.id
    }
}

enum ScrollableTabBarViewConstants {
    static let scrollViewHeight: CGFloat = 40
    static let rightLeftPadding: CGFloat = 20
    static let animationDuration: Double = 0.2
}

struct ScrollableTabBarView<IdentifierType: Hashable>: View {

    @StateObject var viewModel: ScrollableTabBarViewModel<IdentifierType>
    @Binding var selectedTab: IdentifierType
    
    private var horizontalSpacing: CGFloat

    init(items: [ScrollableTabBarItemViewModel<IdentifierType>],
         selectedTab: Binding<IdentifierType>,
         horizontalSpacing: CGFloat = 2) {
        _viewModel = .init(wrappedValue: .init(items: items))
        _selectedTab = selectedTab
        self.horizontalSpacing = horizontalSpacing
    }

    var body: some View {
        scrollableTabView
    }
    
    var scrollableTabView: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: horizontalSpacing) {
                    Color.clear.frame(width: ScrollableTabBarViewConstants.rightLeftPadding)
                    ForEach(viewModel.items, id: \.self) { item in
                        ScrollableTabBarItemView(
                            item: item,
                            tabSelectedAction: { [weak viewModel] in
                                viewModel?.tabSelectedAction()
                            },
                            allowsTapping: $viewModel.allowsTapping,
                            selectedTab: $selectedTab)
                        .id(item.id)
                    }
                    Color.clear.frame(width: ScrollableTabBarViewConstants.rightLeftPadding)
                }
            }
            .onAppear(perform: {
                viewModel.selectedItemChanged(id: selectedTab,
                                              proxy: proxy)
            })
            .onChange(of: selectedTab) { [weak viewModel] id in
                viewModel?.selectedItemChanged(id: id,
                                               proxy: proxy)
            }
            .frame(maxHeight: ScrollableTabBarViewConstants.scrollViewHeight)
            .allowsHitTesting(viewModel.allowsTapping)
        }
    }
}

@MainActor
class ScrollableTabBarViewModel<IdentifierType: Hashable>: ObservableObject {
    var items: [ScrollableTabBarItemViewModel<IdentifierType>]

    @Published var allowsTapping: Bool = true

    init(items: [ScrollableTabBarItemViewModel<IdentifierType>]) {
        self.items = items
    }

    func selectedItemChanged(id: IdentifierType,
                             proxy: ScrollViewProxy ) {
        withAnimation(.easeInOut(duration: ScrollableTabBarViewConstants.animationDuration)) {
            proxy.scrollTo(id, anchor: .center)
        }
    }

    func tabSelectedAction() {
        disableTouchesWhileAnimating()
    }

    func disableTouchesWhileAnimating() {
        allowsTapping = false

        Task {
            try await Task.sleep(nanoseconds: UInt64(ScrollableTabBarViewConstants.animationDuration * 1_000_000))
            self.allowsTapping = true
        }
    }
}

struct ScrollableTabBarItemView<IdentifierType: Hashable>: View {
    var item: ScrollableTabBarItemViewModel<IdentifierType>
    var tabSelectedAction: (() -> Void)?

    @Binding var allowsTapping: Bool
    @Binding var selectedTab: IdentifierType

    var body: some View {
        if selectedTab == item.id {
            text
                .background(Color(.systemGray5))
                .cornerRadius(10)
                .clipped()
        } else {
            text
                .opacity(0.5)
        }
    }

    private var text: some View {
        Button {
            if allowsTapping {
                withAnimation(.easeInOut(duration: 0.2)) {
                    tabSelectedAction?()
                    selectedTab = item.id
                }
            }
        } label: {
            Text(item.title)
                .bold()
                .padding([.top, .bottom], 8)
                .padding([.leading, .trailing], 16)
        }
        .buttonStyle(.plain)
    }
}
