//
//  SeasonsView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 12/8/22.
//

import SwiftUI

struct SeasonsView: View {
    
    var seasons: [Season]
    var navBarTitle: String
    var seriesID: Int
    
    func calculateRowsForSeasons() -> [GridItem] {
        
        switch seasons.count {
        case 1, 2:
            return [GridItem(.flexible(), alignment: .leading)]
        default:
            return [GridItem(.flexible(), alignment: .leading),
                    GridItem(.flexible(), alignment: .leading)]
        }
    }
    
    var body: some View {
        
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: calculateRowsForSeasons(), spacing: 10) {
                ForEach(seasons.indices, id: \.self) { index in
                    
                    if let name = seasons[index].name,
                       let episodes = seasons[index].episode_count,
                       let date = seasons[index].getAirDate() {
                        
                        NavigationLink {
                            SeasonsDetailsTabView(index: index,
                                                  seasons: seasons,
                                                  navBarTitle: navBarTitle,
                                                  seriesID: seriesID)
                        } label: {
                            constructSeason(seasons[index], name, date, episodes)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.top, seasons.count > 2 ? 35 : 5)
                .padding(.bottom, seasons.count > 2 ? 35 : 5)
            }
            .padding([.leading, .trailing], 10)
        }
    }
    
    func constructSeason(_ season: Season,
                         _ name: String,
                         _ date: String,
                         _ episodes: Int) -> some View {
        return HStack() {
            if let imageURL = season.poster_path,
               let url = APIKeys().imageKey + imageURL {
                GenericImageView.init(url: url,
                                      width: 30,
                                      height: 40,
                                      cornerRadius: 0,
                                      showShadow: false)
                
                .aspectRatio(contentMode: .fit)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(name)
                        .bold()
                    Text(date)
                        .bold()
                }
                .font(.system(size: 13))
                
                Text("Episodes: " + String(episodes))
                    .font(.system(size: 11))
            }
        }
        .padding([.top, .bottom], 10)
        .padding([.leading, .trailing], 15)
        .background(Color(.systemGray5))
        .cornerRadius(20)
    }
}
