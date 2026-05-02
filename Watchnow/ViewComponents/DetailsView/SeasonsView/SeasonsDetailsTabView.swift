//
//  SeasonsDetailsTabView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 15/8/22.
//
//  Bottom sheet showing all episodes for a selected season.
//
//  Layout:
//    - Sheet header: season name + episode count
//    - Horizontally-scrollable pill tabs, one per season — purple tint,
//      animated capsule highlight. ScrollViewReader keeps the selected
//      pill centred in view whenever the selection changes (or on appear).
//    - Episode list (or appropriate empty/loading state)
//

import SwiftUI

struct SeasonsDetailsTabView: View {

    @StateObject private var episodesViewModel: EpisodesViewModel
    let seasons: [Season]
    @Binding var selectedSeason: Season
    @Namespace private var pillNamespace

    init(seasons: [Season],
         selectedSeason: Binding<Season>,
         seriesID: Int) {

        self.seasons = seasons
        _selectedSeason = selectedSeason
        _episodesViewModel = StateObject(wrappedValue: EpisodesViewModel(service: ServiceInvocation(),
                                                                         seriesID: seriesID))
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
            seasonTabs
            Divider()
            episodeContent
        }
        .background(Color(.background))
        .task(id: selectedSeason) {
            await episodesViewModel.getEpisodes(seasonNumber: selectedSeason.season_number ?? 0)
        }
    }

    // MARK: - Sheet Header

    private var sheetHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(selectedSeason.name ?? "Season")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)
                .animation(.easeInOut(duration: 0.2), value: selectedSeason)

            // Prefer live episode count from the fetched response; fall back
            // to the season model's own count while loading.
            let count = episodesViewModel.episodes?.episodes?.count
                        ?? selectedSeason.episode_count
                        ?? 0
            Text("\(count) Episodes")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 14)
    }

    // MARK: - Season Pill Tabs

    private var seasonTabs: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(seasons, id: \.self) { season in
                        seasonPill(season, proxy: proxy)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            // Scroll to the active tab on first appear and on every change.
            .onAppear {
                proxy.scrollTo(selectedSeason, anchor: .center)
            }
            .onChange(of: selectedSeason) { season in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    proxy.scrollTo(season, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func seasonPill(_ season: Season, proxy: ScrollViewProxy) -> some View {
        let isSelected = selectedSeason == season

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                selectedSeason = season
            }
        } label: {
            Text(season.name ?? "")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color.accentColor)
                            .matchedGeometryEffect(id: "pill", in: pillNamespace)
                    } else {
                        Capsule()
                            .fill(Color(.secondarySystemBackground))
                    }
                }
        }
        .buttonStyle(.plain)
        .id(season)
    }

    // MARK: - Episode Content

    @ViewBuilder
    private var episodeContent: some View {
        if episodesViewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        } else if episodesViewModel.apiError {
            ContentUnavailableView {
                Label("Couldn't load episodes", systemImage: "exclamationmark.triangle")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.orange)
            } description: {
                Text("Check your connection and try again.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        } else if episodesViewModel.episodes?.air_date != nil {
            let episodes = episodesViewModel.episodes?.episodes ?? []
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(episodes, id: \.self) { episode in
                        EpisodeView(episode: episode)
                    }
                }
            }

        } else {
            ContentUnavailableView {
                Label("Not aired yet", systemImage: "clock")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)
            } description: {
                Text("This season hasn't started yet.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
