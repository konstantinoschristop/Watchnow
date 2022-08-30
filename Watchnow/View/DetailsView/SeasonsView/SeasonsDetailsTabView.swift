//
//  SeasonsDetailsTabView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 15/8/22.
//

import SwiftUI

struct SeasonsDetailsTabView: View {
    
    @StateObject private var episodesViewModel: EpisodesViewModel
    @State var index: Int
    let seasons: [Season]
    let navBarTitle: String
    @Environment(\.presentationMode) var presentation
    
    init(index: Int = 0,
         seasons: [Season],
         navBarTitle: String,
         seriesID: Int) {
        
        self.seasons = seasons
        self.navBarTitle = navBarTitle
        _index = State(initialValue: index)
        _episodesViewModel = StateObject(wrappedValue: EpisodesViewModel.init(service: ServiceInvaction(),
                                                                              seriesID: seriesID))
    }

    var body: some View {
        VStack {
            TabBarView(index: $index, seasons: seasons)
            
            TabView(selection: $index) {
                ForEach(seasons.indices, id: \.self) { index in
                    if let episodes = episodesViewModel.episodes?.episodes {
                        withAnimation {
                            ScrollView {
                                ForEach(episodes, id: \.self) { episode in
                                   EpisodeView(episode: episode)
                                }
                            }
                            .tag(index)
                        }
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .background(Color(.systemGray6))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Button(action : {
            self.presentation.wrappedValue.dismiss()
        }){
            Image(systemName: "arrow.backward.circle.fill")
                .resizable()
                .frame(width: 25, height: 25)
                .foregroundColor(.white)
                .shadow(color: .black, radius: 3)
        })
        .navigationTitle(String(navBarTitle + " - Episodes"))
        .task {
            await episodesViewModel.getEpisodes(seasonNumber: index + 1)
        }
        .onChange(of: index) { newValue in
            episodesViewModel.resetEpisodes()
            Task {
                await episodesViewModel.getEpisodes(seasonNumber: newValue + 1)
            }
        }
    }
}

struct TabBarView: View {
    
    private let leftOffset: CGFloat = 0.15
    @Binding var index: Int
    let seasons: [Season]
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(seasons.indices, id: \.self) { index in
                        let title = Text(seasons[index].name ?? "")
                            .bold()
                            .id(index)
                            .onTapGesture {
                                withAnimation() {
                                    self.index = index
                                }
                            }
                        if self.index == index {
                            title.foregroundColor(Color(.systemBackground))
                                .colorInvert()
                                .padding(.all, 10)
                                .background(Color(.systemGray5))
                                .cornerRadius(20)
                        } else {
                            title.foregroundColor(.gray)
                        }
                    }
                    .font(.custom("AvenirNext-Regular", size: 20))
                    .padding(.top, 20)
                    .padding(.horizontal, 5)
                }
                .padding([.leading, .trailing], 20)
            }
            .onChange(of: index) { value in
                withAnimation(.easeInOut) {
                    proxy.scrollTo(value, anchor: UnitPoint(x: UnitPoint.leading.x + leftOffset, y: UnitPoint.leading.y + leftOffset))
                }
            }
            .onAppear {
                proxy.scrollTo(index, anchor: UnitPoint(x: UnitPoint.leading.x + leftOffset, y: UnitPoint.leading.y + leftOffset))
            }
        }
    }
}
