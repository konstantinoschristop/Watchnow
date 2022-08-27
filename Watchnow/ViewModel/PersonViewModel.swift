//
//  PersonViewModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 16/8/22.
//

import Foundation

@MainActor
class PersonViewModel: ObservableObject {
    
    @Published private(set) var person: PersonModel?
    @Published var imageHeight: Float = 400
    
    private let service: ServiceInvaction
    let personID: Int
    
    init(service: ServiceInvaction,
         personID: Int) {
        
        self.service = service
        self.personID = personID
    }
    
    func getPersonDetails() async {
            
        do {
            self.person = try await service.fetchPerson(personID: personID)
        } catch {
            print(error)
        }
    }
}
