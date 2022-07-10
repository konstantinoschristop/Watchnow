//
//  SearchView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 10/7/22.
//

import SwiftUI

struct SearchView: View {
    
    @StateObject var searchVM = SearchViewModel.init(service: ServiceInvaction.init())
    @State var searchInput = ""
    
    var body: some View {
        
        VStack {
            ZStack {
                Rectangle()
                    .fill(Color(.systemGray6))
                    .foregroundColor(Color(.systemBackground))
                    .cornerRadius(13)
                HStack {
                    Image(systemName: "magnifyingglass")
                    
                    TextField("Search movies and tv series...", text: $searchInput)
                        .onSubmit {
                            Task {
                                if searchInput != "" {
                                    await searchVM.getResults(search: searchInput)
                                }
                            }
                        }
                }
                .padding(.all, 10)
            }
            .padding()
            .frame(height: 40)
            
            Spacer()
            
            Group {
                if let results = searchVM.result?.results?.filter { $0.poster_path != nil } {
                    if results == [] {
                        VStack {
                            Spacer()
                            Text("No results found. Try searching again with a different keyword.")
                                .padding()
                            Spacer()
                        }
                    } else {
                        List {
                            SearchResults(results: results)
                                .listRowSeparatorTint(.clear)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
                        }
                    }
                }
            }
            .refreshable {
                if searchInput != "" {
                    await searchVM.getResults(search: searchInput)
                }
            }
        }
        .navigationTitle("Search")
    }
}

struct SearchResults: View {
    
    var results: [Result]
    
    var body: some View {
        
        ForEach(results, id: \.self) { result in
            NavigationLink {
                ContentDetailsView(result: result, screenType: result.media_type == "movie" ? .movie : .tv)
            } label: {
                ZStack {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .cornerRadius(10)
                    HStack {
                        if let imageURL = result.poster_path,
                           let url = APIKeys().imageKey + imageURL {
                            
                            GenericImageView(url: url,
                                             width: 80,
                                             height: 120)
                        }
                        
                        VStack {
                            Text(result.getResultTitle())
                                .font(.system(size: 16, weight: .bold))
                            Spacer()
                                .frame(height: 20)
                            
                            HStack {
                                Text("Release Date: " + result.getReleaseDate())
                                Spacer()
                                Text("Type: " + result.getMediaType())
                            }
                            .font(.system(size: 11, weight: .light))
                        }
                        .padding()
                    }
                }
            }
        }
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
