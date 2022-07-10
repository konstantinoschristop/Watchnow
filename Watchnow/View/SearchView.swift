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
                    .foregroundColor(Color(.systemBackground))
                   
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
                        .disableAutocorrection(true)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding()
            .frame(height: 40)
            .cornerRadius(13)
            
            Spacer()
               
            Group {
                if let results = searchVM.result?.results {
                     SearchResults(results: results)
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
        
        List {
            ForEach(results, id: \.self) { result in
                NavigationLink {
                    ContentDetailsView(result: result, screenType: result.media_type == "movie" ? .movie : .tv)
                } label: {
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
