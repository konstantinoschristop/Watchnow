//
//  SearchView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 10/7/22.
//

import SwiftUI
import AlertToast

struct SearchView: View {
    
    @StateObject var searchVM = SearchViewModel.init(service: ServiceInvocation.init())
    @State var enablePicker = false
    @State var showGenres = false
    @State var searchInput = ""
    
    init() {
        UITextField.appearance().clearButtonMode = .whileEditing
    }
    
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
                        .submitLabel(.search)
                        .onSubmit {
                            self.hideKeyboard()
                        }
                        .onChange(of: searchInput) { newValue in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: {
                                guard newValue == searchInput else {
                                    return
                                }
                                
                                Task {
                                    if searchInput != "" {
                                        self.enablePicker = true
                                        await searchVM.getResults(search: searchInput)
                                    }
                                }
                            })
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
            
            if showGenres {
                let rows = [GridItem(.flexible(), alignment: .leading),
                            GridItem(.flexible(), alignment: .trailing)]
                
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: rows, spacing: 0) {
                        ForEach(GendreIDs.allCases, id: \.self) { genre in
                            NavigationLink {
                                
                            } label: {
                                Text(genre.getNameForGenre())
                                    .frame(width: 150, height: 150, alignment: .center)
                                    .background(LinearGradient(gradient: Gradient(colors: [.gray.opacity(0.6),
                                                                                           genre.getBackgroundColorForGenre().opacity(0.6)]),
                                                               startPoint: .topLeading,
                                                               endPoint: .bottomTrailing))
                                    .cornerRadius(10)
                                    .padding()
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
            }
            
            Group {
                if let results = searchVM.result?.results?.filter { $0.poster_path != nil && $0.media_type != "person" || $0.profile_path != nil && $0.media_type == "person" } {
                    if results == [] {
                        Text("No results found. Try searching again with a different keyword.")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            if searchVM.listNeedsUpdate {
                                SearchResults(results: results,
                                              chooserSelection: $searchVM.selectedChooser,
                                              viewModel: searchVM)
                            } else {
                                SearchResults(results: results,
                                              chooserSelection: $searchVM.selectedChooser,
                                              viewModel: searchVM)
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .toast(isPresenting: $searchVM.showAddedAlert, alert: {
                AlertToast(type: .systemImage("checkmark.circle", .green), title: "Added to Watchlist")
            })
            .toast(isPresenting: $searchVM.showRemovedAlert, alert: {
                AlertToast(type: .systemImage("x.circle", .red), title: "Removed from Watchlist")
            })
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
    let viewModel: SearchViewModel
    var filtered: [Result] = []
    
    init(results: [Result],
         chooserSelection: Binding<SearchViewModel.SearchChooserOptions>,
         viewModel: SearchViewModel) {
        
        self._chooserSelection = chooserSelection
        self.viewModel = viewModel
        
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
            Text("No results found for this filter.")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .listRowSeparatorTint(.clear)
                .listRowBackground(Color(.systemGray6))
        } else {
            GenericListView(results: filtered, viewModel: viewModel)
        }
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    func showKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.becomeFirstResponder), to: nil, from: nil, for: nil)
    }
}
