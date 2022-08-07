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
           GenericListView(results: filtered)
        }
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
