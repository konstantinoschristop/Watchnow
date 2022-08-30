//
//  EpisodesView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 16/8/22.
//

import SwiftUI

struct EpisodeView: View {
    
    var episode: Episode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let name = episode.name,
               let rating = episode.vote_average,
               let airDate = episode.air_date {
                
                HStack {
                    Text("E" + String(episode.episode_number ?? 0) + ": " + name)
                        .bold()
                        .lineLimit(1)
                        .foregroundColor(Color(.systemBackground))
                        .colorInvert()
                    
                    Spacer()
                    
                    HStack {
                        Text(airDate)
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.orange)
                            Text(String(format: "%.1f", rating))
                        }
                    }
                }
                
                if let overview = episode.overview,
                   overview.isEmpty == false {
                    Text(overview)
                } else {
                    Text("Overview not available.")
                        .italic()
                }
            }
        }
        .font(.custom("AvenirNext-Regular", size: 15))
        .padding()
        .cornerRadius(10)
        .foregroundColor(.gray)
    }
}

struct EpisodeView_Previews: PreviewProvider {
    static var previews: some View {
        
        let episode = Episode.init(id: 1,
                                   name: "HarryHarryHarryHarryHarryHarryHarryHarryHarry",
                                   overview: "yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yyo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo yo",
                                   still_path: nil,
                                   vote_average: 6.7,
                                   vote_count: 1000,
                                   air_date: "10/02/2002",
                                   episode_number: 1)
        
        EpisodeView(episode: episode)
    }
}
