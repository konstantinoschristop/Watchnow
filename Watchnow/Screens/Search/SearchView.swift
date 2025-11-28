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
    @Namespace private var namespace
    
    var body: some View {
        
        VStack(spacing: 0) {
            searchResultsView
//            AdBannerView()
//                .frame(height: 50)
//                .padding(.bottom)
        }
        .toast(isPresenting: $searchVM.showAddedAlert, alert: {
            AlertToast(displayMode: .hud, type: .systemImage("checkmark.circle", .green), title: "Added to Watchlist")
        })
        .toast(isPresenting: $searchVM.showRemovedAlert, alert: {
            AlertToast(displayMode: .hud, type: .systemImage("x.circle", .red), title: "Removed from Watchlist")
        })
        .searchable(text: $searchInput)
        .onChange(of: searchInput) { _ ,newValue in
            guard !newValue.isEmpty, newValue.count > 1 else { return }

            Task {
                // Wait 0.6s to debounce
                try? await Task.sleep(for: .seconds(0.6))

                // Check if the text is still the same (user didn’t keep typing)
                guard newValue == searchInput else { return }

                await searchVM.getResults(search: newValue)
                await MainActor.run {
                    enablePicker = true
                    hideKeyboard()
                }
            }
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
        .padding()
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
        
        if let results = searchVM.results{
            if results.isEmpty == false {
                List {
                    if searchVM.filteredResults.isEmpty {
                        ContentUnavailableView("No results found for this filter.", systemImage: "xmark.circle")
                            .listRowSeparatorTint(.clear)
                            .listRowBackground(Color(.systemGray6))
                            .listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10))
                    } else {
                        GenericListView(results: $searchVM.filteredResults,
                                        viewModel: searchVM,
                                        namespace: namespace)
                    }
                }
                .listStyle(.plain)
                .safeAreaInset(edge: .bottom, content: {
                    pickerView
                })
                .scrollDismissesKeyboard(.interactively)
            } else {
                ContentUnavailableView("No results found. Try searching again with a different keyword.", systemImage: "xmark.circle")
            }
        } else {
            ContentUnavailableView("Search Movies, TV Series or Actors",
                                   systemImage: "magnifyingglass")
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
