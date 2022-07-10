//
//  SearchViewModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 10/7/22.
//

import Foundation

@MainActor
class SearchViewModel: ObservableObject {
    
    @Published private(set) var result: SearchModel?
    
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
