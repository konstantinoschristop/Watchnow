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
    @State var isSeasonsSheetPresented = false
    @State var selectedSeason: Season
    
    init(seasons: [Season],
         navBarTitle: String,
         seriesID: Int) {
        
        self.seasons = seasons
        self.navBarTitle = navBarTitle
        self.seriesID = seriesID
        self.selectedSeason = seasons.first ?? .init()
    }
    
    func calculateRowsForSeasons() -> [GridItem] {
        
        switch seasons.count {
        case 1...2:
            return [GridItem(.flexible(), alignment: .leading)]
        case 3...10:
            return [GridItem(.flexible(), alignment: .leading),
                    GridItem(.flexible(), alignment: .leading)]
        default:
            return [GridItem(.flexible(), alignment: .leading),
                    GridItem(.flexible(), alignment: .leading),
                    GridItem(.flexible(), alignment: .leading)]
        }
    }
    
    var body: some View {
        
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: calculateRowsForSeasons(), spacing: 10) {
                ForEach(seasons, id: \.self) { season in
                    if season.name?.isEmpty == false {
                        Button {
                            selectedSeason = season
                            isSeasonsSheetPresented.toggle()
                        } label: {
                            constructSeason(season)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding([.leading, .trailing], 10)
        }
        .sheet(isPresented: $isSeasonsSheetPresented) {
            SeasonsDetailsTabView(seasons: seasons,
                                  selectedSeason: $selectedSeason,
                                  seriesID: seriesID)
            .presentationDetents([.large])
        }
    }
    
    func constructSeason(_ season: Season) -> some View {
        return HStack() {
            if let imageURL = season.poster_path {
                
                let url = API.Common.imageUrl(imageId: imageURL)
                
                GenericImageView.init(url: url,
                                      width: 30,
                                      height: 40,
                                      cornerRadius: 0,
                                      showShadow: false)
                
                .aspectRatio(contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: 0)
                    .frame(width: 30, height: 40, alignment: .center)
                    .foregroundStyle(Color.gray)
            }
            
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(season.name ?? "")
                        .bold()
                    Text(season.getAirDate() ?? "")
                        .bold()
                }
                .font(.system(size: 13))
                
                if let episodes = season.episode_count {
                    Text("Episodes: " + String(episodes))
                        .font(.system(size: 11))
                }
            }
        }
        .padding([.top, .bottom], 10)
        .padding([.leading, .trailing], 15)
        .background(Color(.secondaryBackground))
        .cornerRadius(20)
    }
}
