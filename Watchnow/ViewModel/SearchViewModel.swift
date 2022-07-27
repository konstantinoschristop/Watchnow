//
//  SearchViewModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 10/7/22.
//

import Foundation

@MainActor
class SearchViewModel: ObservableObject {
    
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
    @Published var selectedChooser: SearchChooserOptions = .all
    
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
}
