//
//  TrendingSeriesViewModel.swift
//  Watchnow
//
//  Created by k.christopoulos on 30/11/21.
//

import Foundation

@MainActor
class TrendingSeriesViewModel: ObservableObject {
    
    @Published private(set) var trendingSeries: TrendingSeriesModel = TrendingSeriesModel.init(results: [])
    
    private let service: SerieService
    
    init(service: SerieService) {
        self.service = service
    }
    
    func getTrendingSeries() async {
        
        do {
            self.trendingSeries = try await service.fetchTrendingSeries()
        } catch {
            print(error)
        }
    }
}
