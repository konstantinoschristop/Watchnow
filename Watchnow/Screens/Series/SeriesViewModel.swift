//
//  SeriesViewModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 30/7/22.
//

import Foundation

@MainActor
class SeriesViewModel: BaseContentViewModel {
    
    @Published var model: SeriesModel
    
    init(model: SeriesModel,
         service: SerieService = SerieService()) {
        
        self.model = model
        super.init(service: service)
    }
}

extension SerieService: ContentService {
    func fetchTrending(page: Int) async throws -> GenericReultResponse {
        try await fetchTrendingSeries(page: page)
    }
    
    func fetchPopular(page: Int) async throws -> GenericReultResponse {
        try await fetchPopularSeries(page: page)
    }
    
    func fetchUpcomingOrAiring(page: Int) async throws -> GenericReultResponse {
        try await fetchAiringTodaySeries(page: page)
    }
    
    func fetchLatest(page: Int) async throws -> GenericReultResponse {
        try await fetchLatestSeries(page: page)
    }
}
