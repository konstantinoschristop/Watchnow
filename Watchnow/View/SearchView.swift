//
//  SearchView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 10/7/22.
//

import SwiftUI

struct SearchView: View {
    
    @StateObject var searchVM = SearchViewModel.init(service: ServiceInvaction.init())
    @State var enablePicker = false
    @State var searchInput = ""
    
    var body: some View {
        
        VStack {
            ZStack {
                Rectangle()
                    .fill(Color(.systemGray4))
                    .foregroundColor(Color(.systemBackground))
                    .cornerRadius(13)
                HStack {
                    Image(systemName: "magnifyingglass")
                    
                    TextField("Search movies and tv series...", text: $searchInput)
                    .onSubmit {
                        Task {
                            if searchInput != "" {
                                self.enablePicker = true
                                await searchVM.getResults(search: searchInput)
                            }
                        }
                    }
                }
                .padding(.all, 10)
            }
            .padding()
            .frame(height: 40)
            
            if enablePicker {
                withAnimation {
                    Picker(selection: $searchVM.selectedChooser) {
                        Text(SearchViewModel.SearchChooserOptions.all.getTitle()).tag(SearchViewModel.SearchChooserOptions.all)
                        Text(SearchViewModel.SearchChooserOptions.movies.getTitle()).tag(SearchViewModel.SearchChooserOptions.movies)
                        Text(SearchViewModel.SearchChooserOptions.series.getTitle()).tag(SearchViewModel.SearchChooserOptions.series)
                        Text(SearchViewModel.SearchChooserOptions.actors.getTitle()).tag(SearchViewModel.SearchChooserOptions.actors)
                    } label: {}
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.init(top: 10, leading: 25, bottom: 10, trailing: 25))
                }
            }
  
            Spacer()
            
            Group {
                if let results = searchVM.result?.results?.filter { $0.poster_path != nil && $0.media_type != "person" || $0.poster_path == nil && $0.media_type == "person" } {
                    if results == [] {
                        VStack {
                            Spacer()
                            Text("No results found. Try searching again with a different keyword.")
                                .padding()
                            Spacer()
                        }
                    } else {
                        ScrollView {
                            SearchResults(results: results, chooserSelection: $searchVM.selectedChooser)
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
    
    @Binding var chooserSelection: SearchViewModel.SearchChooserOptions
    var filtered: [Result] = []
    
    init(results: [Result],
         chooserSelection: Binding<SearchViewModel.SearchChooserOptions>) {
        
        self._chooserSelection = chooserSelection
        
        if chooserSelection.wrappedValue.rawValue == "All" {
            self.filtered = results
        } else {
            results.forEach { result in
                if result.getMediaType() == chooserSelection.wrappedValue.rawValue {
                    self.filtered.append(result)
                }
            }
        }
    }
    
    var body: some View {
        
        if filtered.isEmpty {
            VStack {
                Spacer()
                Text("No results found for this filter.")
                    .padding()
                Spacer()
            }
        } else {
            self.getResultView(results: filtered)
        }
    }
    
    func getResultView(results: [Result]) -> some View {
        
        return  Group {
            ForEach(filtered, id: \.self) { result in
                NavigationLink {
                    switch result.getMediaType() {
                    case "Actor":
                        ActorDetailsView(actorID: result.id)
                    default:
                        ContentDetailsView(result: result, screenType: result.media_type == "movie" ? .movie : .tv)
                    }
                } label: {
                    self.constructResult(result: result)
                }
            }
        }
    }
    
    func constructResult(result: Result) -> some View {
        return ZStack {
            Rectangle()
                .fill(Color(.systemGray5))
                .cornerRadius(10)
            HStack {
                if let imageURL = result.getResultPosterURL(),
                   let url = APIKeys().imageKey + imageURL {
                    
                    GenericImageView(url: url,
                                     width: 70,
                                     height: 90,
                                     cornerRadius: 10,
                                     showShadow: false)
                }
                
                VStack(alignment: .leading) {
                    Text(result.getResultTitle())
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                        .frame(height: 10)
                    
                    HStack {
                        Text(result.getReleaseDate() + result.getMediaType())
                        Spacer()
                    }
                    .font(.system(size: 12, weight: .light))
                }
                .foregroundColor(Color(.systemBackground))
                .colorInvert()
                .padding()
            }
        }
        .padding(.init(top: 0, leading: 15, bottom: 0, trailing: 15))
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
