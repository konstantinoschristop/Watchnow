//
//  CreditsViewModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 13/2/22.
//

import Foundation

@MainActor
class CreditsViewModel: ObservableObject {
    
    @Published private(set) var credits: CreditsModel?
    
    private let service: ServiceInvaction
    let screenType: ScreenTypes
    let id: String
    
    init(service: ServiceInvaction, screenType: ScreenTypes, id: String) {
        self.service = service
        self.screenType = screenType
        self.id = id
    }
    
    func getCredits() async {
        
        do {
            self.credits = try await service.fetchCredits(screenType: self.screenType, id: self.id)
        } catch {
            print(error)
        }
    }
}
