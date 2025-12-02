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
    @State var showLoader = false
    
    init(seasons: [Season],
         selectedSeason: Binding<Season>,
         seriesID: Int) {
        
        self.seasons = seasons
        _selectedSeason = selectedSeason
        _episodesViewModel = StateObject(wrappedValue: EpisodesViewModel.init(service: ServiceInvocation(),
                                                                              seriesID: seriesID))
    }
    
    var body: some View {
        VStack {
            ScrollableTabBar(items: seasons,
                             selectedItem: $selectedSeason,
                             titleForItem: { $0.name ?? "Unknown" })
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
        .background(Color(.background))
        .task(id: selectedSeason) {
            await episodesViewModel.getEpisodes(seasonNumber: selectedSeason.season_number ?? 0)
        }
    }
}
