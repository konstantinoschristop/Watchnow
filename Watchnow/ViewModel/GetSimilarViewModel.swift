//
//  GetSimilarViewModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 5/6/22.
//

import Foundation

@MainActor
class GetSimilarViewModel: ObservableObject {
    
    @Published private(set) var similar: GetSimilarModel?
    
    private let service: ServiceInvaction
    let screenType: ScreenTypes
    let id: String
    
    init(service: ServiceInvaction, screenType: ScreenTypes, id: String) {
        self.service = service
        self.screenType = screenType
        self.id = id
    }
    
    func getSimilars() async {
        
        do {
            self.similar = try await service.fetchSimilars(screenType: self.screenType, id: self.id)
        } catch {
            print(error)
        }
    }
}
