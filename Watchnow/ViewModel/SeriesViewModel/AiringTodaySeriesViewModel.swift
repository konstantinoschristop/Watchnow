//
//  AiringTodaySeriesViewModel.swift.swift
//  Watchnow
//
//  Created by k.christopoulos on 30/11/21.
//

import Foundation

@MainActor
class AiringTodaySeriesViewModel: ObservableObject {
    
    @Published private(set) var airingTodaySeries: AiringTodaySeriesModel = AiringTodaySeriesModel.init(results: [])
    
    private let service: SerieService
    
    init(service: SerieService) {
        self.service = service
    }
    
    func getAiringTodaySeries() async {
        
        do {
            self.airingTodaySeries = try await service.fetchAiringTodaySeries()
        } catch {
            print(error)
        }
    }
}
