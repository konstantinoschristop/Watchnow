//
//  SearchViewModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 10/7/22.
//

import Foundation

@MainActor
protocol BaseSwipeActionsProtocol {
    var showRemovedAlert: Bool { get set }
    var showAddedAlert: Bool { get set }
    var listNeedsUpdate: Bool { get set }
    func refreshDataIfNeeded()
}

@MainActor
class SearchViewModel: ObservableObject, BaseSwipeActionsProtocol {
    
    @Published private var model: SearchModel
    @Published var showRemovedAlert = false
    @Published var showAddedAlert = false
    @Published var listNeedsUpdate = false {
        didSet {
            refreshDataIfNeeded()
        }
    }
    @Published var apiError: Bool = false
    private let service: ServiceInvocation
    
    init(model: SearchModel,
         service: ServiceInvocation = .init()) {
        
        self.model = model
        self.service = service
    }
    
    func getResults(search: String) async {
        
        do {
            searchResponse = try await service.fetchSearchResults(search: search)
            cleanUpResults(results: searchResponse)
        } catch {
            apiError = true
        }
    }
    
    private func cleanUpResults(results: SearchResponse?) {
        
        self.results = results?.results?.filter { $0.poster_path != nil && $0.media_type != "person" ||
                                                  $0.profile_path != nil && $0.media_type == "person" }
    }
    
    func getFilteredArray() -> [Result] {
        
        if selectedChooser == .all {
            return results ?? []
        } else {
            return results?.filter { $0.getMediaType() == selectedChooser.rawValue } ?? []
        }
    }
    
    func refreshDataIfNeeded() {
        cleanUpResults(results: searchResponse)
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
    
    var selectedChooser: SearchModel.SearchChooserOptions {
        get { model.selectedChooser }
        set { model.selectedChooser = newValue }
    }
}
