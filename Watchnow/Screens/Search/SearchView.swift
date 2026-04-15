//
//  SearchView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 10/7/22.
//

import SwiftUI
import AlertToast

struct SearchView: View {
    
    @ObservedObject var viewModel: SearchViewModel
    @State var searchInput = ""
    @Namespace private var namespace
    
    var body: some View {
        
        VStack(spacing: 0) {
            searchResultsView
//            AdBannerView()
//                .frame(height: 50)
//                .padding(.bottom)
        }
        .toast(isPresenting: $viewModel.showAddedAlert, alert: {
            AlertToast(displayMode: .hud, type: .systemImage("checkmark.circle", .green), title: "Added to Watchlist")
        })
        .toast(isPresenting: $viewModel.showRemovedAlert, alert: {
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

                await viewModel.getResults(search: newValue)
                await MainActor.run {
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
        Picker("", selection: $viewModel.selectedChooser) {
            ForEach(options, id:\.hashValue) { option in
                Text(option.getTitle())
                    .tag(option)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
    }
    
    @ViewBuilder
    var searchResultsView: some View {
        
        if let results = viewModel.results{
            if results.isEmpty == false {
                List {
                    if viewModel.filteredResults.isEmpty {
                        ContentUnavailableView("No results found for this filter.", systemImage: "xmark.circle")
                            .listRowSeparatorTint(.clear)
                            .listRowBackground(Color(.background))
                            .listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10))
                    } else {
                        GenericListView(results: $viewModel.filteredResults,
                                        viewModel: viewModel,
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

