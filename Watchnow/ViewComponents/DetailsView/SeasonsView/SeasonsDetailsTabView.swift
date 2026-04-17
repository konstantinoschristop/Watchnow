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
    @Binding var selectedSeason: Season

    init(seasons: [Season],
         selectedSeason: Binding<Season>,
         seriesID: Int) {

        self.seasons = seasons
        _selectedSeason = selectedSeason
        _episodesViewModel = StateObject(wrappedValue: EpisodesViewModel(service: ServiceInvocation(),
                                                                         seriesID: seriesID))
    }

    var body: some View {
        VStack {
            ScrollableTabBar(items: seasons,
                             selectedItem: $selectedSeason,
                             titleForItem: { $0.name ?? "Unknown" })
            .padding(.top)

            if episodesViewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if episodesViewModel.apiError {
                ContentUnavailableView("Couldn't load episodes",
                                       systemImage: "exclamationmark.triangle",
                                       description: Text("Check your connection and try again."))
            } else if episodesViewModel.episodes?.air_date != nil {
                let episodes = episodesViewModel.episodes?.episodes ?? []
                ScrollView {
                    ForEach(episodes, id: \.self) { episode in
                        EpisodeView(episode: episode)
                    }
                }
            } else {
                ContentUnavailableView("Not aired yet",
                                       systemImage: "clock",
                                       description: Text("This season hasn't started yet."))
            }
        }
        .background(Color(.background))
        .task(id: selectedSeason) {
            await episodesViewModel.getEpisodes(seasonNumber: selectedSeason.season_number ?? 0)
        }
    }
}
