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
    
    enum SearchChooserOptions: String, CaseIterable {
        case all = "All"
        case movies = "Movie"
        case series = "TV Serie"
        case actors = "Actor"
        
        func getTitle() -> String {
            
            switch self {
            case .all:
                return "All"
            case .movies:
                return "Movies"
            case .series:
                return "TV Series"
            case .actors:
                return "Actors"
            }
        }
    }
    
    @Published private(set) var result: SearchModel?
    @Published var selectedChooser: SearchChooserOptions = .all {
        didSet {
            listNeedsUpdate = false
        }
    }
    @Published var showRemovedAlert = false {
        didSet {
            listNeedsUpdate = false
        }
    }
    @Published var showAddedAlert = false {
        didSet {
            listNeedsUpdate = false
        }
    }
    @Published var listNeedsUpdate = false
    
    private let service: ServiceInvaction
    
    init(service: ServiceInvaction) {
        self.service = service
    }
    
    func getResults(search: String) async {
        
        do {
            self.result = try await service.fetchSearchResults(search: search)
        } catch {
            print(error)
        }
    }
    
    func refreshDataIfNeeded() {
    }
}
