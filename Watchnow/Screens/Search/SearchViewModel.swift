//
//  SearchViewModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 10/7/22.
//

import Foundation

@MainActor
protocol BaseSwipeActionsProtocol: AnyObject {
    var showRemovedAlert: Bool { get set }
    var showAddedAlert: Bool { get set }
    func itemRemoved(result: Result)
    func watchedItemRemoved(result: Result)
}

extension BaseSwipeActionsProtocol {
    func itemRemoved(result: Result) {}
    func watchedItemRemoved(result: Result) {}
}

@MainActor
class SearchViewModel: ObservableObject, BaseSwipeActionsProtocol {
 
    @Published private var model: SearchModel
    @Published var showRemovedAlert = false
    @Published var showAddedAlert = false
    
    @Published var apiError: Bool = false
    @Published var isSearching: Bool = false
    private let service: any DetailServiceProtocol

    init(model: SearchModel,
         service: any DetailServiceProtocol = ServiceInvocation()) {

        self.model = model
        self.service = service
        self.model.recentSearches = SearchHistoryManager.recentSearches
    }
    
    func getResults(search: String) async {
        apiError = false
        isSearching = true
        defer { isSearching = false }
        do {
            searchResponse = try await service.fetchSearchResults(search: search)
            cleanUpResults(results: searchResponse)
            SearchHistoryManager.addSearch(search)
            model.recentSearches = SearchHistoryManager.recentSearches
        } catch {
            apiError = true
        }
    }

    func clearResults() {
        results = nil
        apiError = false
    }

    func removeRecentSearch(_ query: String) {
        SearchHistoryManager.removeSearch(query)
        model.recentSearches = SearchHistoryManager.recentSearches
    }

    func clearRecentSearches() {
        SearchHistoryManager.clearAll()
        model.recentSearches = SearchHistoryManager.recentSearches
    }
    
    private func cleanUpResults(results: SearchResponse?) {
        
        self.results = results?.results?.filter { $0.poster_path != nil && $0.media_type != "person" ||
                                                  $0.profile_path != nil && $0.media_type == "person" }
    }
}

extension SearchViewModel {
    
    var searchResponse: SearchResponse? {
        get { model.searchResponse }
        set { model.searchResponse = newValue }
    }
    
    var results: [Result]? {
        get { model.results }
        set { model.results = newValue }
    }
    
    var filteredResults: [Result] {
        get { model.filteredResults }
        set { model.filteredResults = newValue }
    }

    var selectedChooser: SearchModel.SearchChooserOptions {
        get { model.selectedChooser }
        set { model.selectedChooser = newValue }
    }

    var recentSearches: [String] {
        get { model.recentSearches }
        set { model.recentSearches = newValue }
    }
}
