//
//  GenreViewModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 10/7/22.
//

import Foundation

@MainActor
class GenreViewModel: ObservableObject {
    
    @Published private(set) var genres: GenreModel?
    
    private let service: ServiceInvaction
    
    init(service: ServiceInvaction) {
        self.service = service
    }
    
    func getGenres(screenType: ScreenTypes) async {
        
        do {
            self.genres = try await service.fetchGenres(screenType: screenType)
        } catch {
            print(error)
        }
    }
}
