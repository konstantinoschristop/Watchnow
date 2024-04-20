//
//  SearchView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 10/7/22.
//

import SwiftUI
import AlertToast

struct SearchView: View {
    
    @StateObject var searchVM: SearchViewModel
    @State var enablePicker = false
    @State var showGenres = false
    @State var searchInput = ""
    
    var body: some View {
        
        VStack(spacing: 0) {
          //  genresView
            searchResultsView
//            AdBannerView()
//                .frame(height: 50)
//                .padding(.bottom)
        }
        .toast(isPresenting: $searchVM.showAddedAlert, alert: {
            AlertToast(displayMode: .banner(.slide), type: .systemImage("checkmark.circle", .green), title: "Added to Watchlist")
        })
        .toast(isPresenting: $searchVM.showRemovedAlert, alert: {
            AlertToast(displayMode: .banner(.slide), type: .systemImage("x.circle", .red), title: "Removed from Watchlist")
        })
//        .refreshable {
//            if searchInput != "" {
//                await searchVM.getResults(search: searchInput)
//                self.hideKeyboard()
//            }
//        }
        .searchable(text: $searchInput)
        .onChange(of: searchInput) { newValue in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: {
                guard newValue == searchInput,
                      searchInput.isEmpty == false,
                      newValue.count > 2 else {
                    return
                }
                
                Task {
                    await searchVM.getResults(search: searchInput)
                    self.enablePicker = true
                    self.hideKeyboard()
                }
            })
        }
    }
}

extension SearchView {
    
    @ViewBuilder
    var pickerView: some View {
        let options = SearchModel.SearchChooserOptions.allCases
        Picker("", selection: $searchVM.selectedChooser) {
            ForEach(options, id:\.hashValue) { option in
                Text(option.getTitle())
                    .tag(option)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
    }
    
    @ViewBuilder
    var genresView: some View {
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
    }
    
    @ViewBuilder
    var searchResultsView: some View {
        
        if let results = searchVM.results {
            if results.isEmpty == false {
                let filtered = searchVM.getFilteredArray()
                List {
                    if filtered.isEmpty {
                        Text("No results found for this filter.")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .listRowSeparatorTint(.clear)
                            .listRowBackground(Color(.systemGray6))
                    } else {
                        if searchVM.listNeedsUpdate {
                            GenericListView(results: filtered, viewModel: searchVM)
                        } else {
                            GenericListView(results: filtered, viewModel: searchVM)
                        }
                    }
                }
                .listStyle(.plain)
                .toolbar {
                    ToolbarItem(placement: .status) {
                        pickerView
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            } else {
                Text("No results found. Try searching again with a different keyword.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            VStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .foregroundColor(Color(.systemGray4))
                Text("Search Movies, TV Series or Actors")
                    .font(.system(size: 18, weight: .bold))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .onTapGesture {
                self.hideKeyboard()
            }
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
