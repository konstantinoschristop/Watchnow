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
         service: SeriesService = SeriesService()) {
        
        self.model = model
        super.init(service: service)
    }
}

extension SeriesService: ContentService {
    var screenType: ScreenTypes { .tv }

    func fetchTrending(page: Int) async throws -> GenericResultResponse {
        try await fetchTrendingSeries(page: page)
    }
    
    func fetchPopular(page: Int) async throws -> GenericResultResponse {
        try await fetchPopularSeries(page: page)
    }
    
    func fetchUpcomingOrAiring(page: Int) async throws -> GenericResultResponse {
        try await fetchAiringTodaySeries(page: page)
    }
    
    func fetchLatest(page: Int) async throws -> GenericResultResponse {
        try await fetchLatestSeries(page: page)
    }

    func fetchTopRated(page: Int) async throws -> GenericResultResponse {
        try await fetchTopRatedSeries(page: page)
    }
}
