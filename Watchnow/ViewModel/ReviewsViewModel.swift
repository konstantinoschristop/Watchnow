//
//  ReviewsViewModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 5/6/22.
//

import Foundation

@MainActor
class ReviewsViewModel: ObservableObject {
    
    @Published private(set) var reviews: ReviewsModel?
    
    private let service: ServiceInvaction
    let screenType: ScreenTypes
    let id: String
    
    init(service: ServiceInvaction, screenType: ScreenTypes, id: String) {
        self.service = service
        self.screenType = screenType
        self.id = id
    }
    
    func getReviews() async {
        
        do {
            self.reviews = try await service.fetchReviews(screenType: self.screenType, id: self.id)
        } catch {
            print(error)
        }
    }
}
