//
//  PopularSeriesViewModel.swift
//  Watchnow
//
//  Created by k.christopoulos on 30/11/21.
//

import Foundation

@MainActor
class PopularSeriesViewModel: ObservableObject {
    
    @Published private(set) var popularSeries: PopularSeriesModel?
    
    private let service: SerieService
    
    init(service: SerieService) {
        self.service = service
    }
    
    func getPopularSeries() async {
        
        do {
            self.popularSeries = try await service.fetchPopularSeries()
        } catch {
            print(error)
        }
    }
}
