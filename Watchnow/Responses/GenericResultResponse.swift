//
//  UpcomingMoviesModel.swift
//  Watchnow
//
//  Created by k.christopoulos on 1/8/21.
//

import Foundation

enum ViewSections {
    case upcomingMovies
    case popularMovies
    case trendingMovies
    case latestMovies
    
    case popularSeries
    case airingTodaySeries
    case trendingSeries
    case latestSeries
}

extension ViewSections {
    var screenType: ScreenTypes {
        switch self {
        case .upcomingMovies, .popularMovies, .trendingMovies, .latestMovies:
            return .movie
        case .popularSeries, .airingTodaySeries, .trendingSeries, .latestSeries:
            return .tv
        }
    }
    
    var title: String {
        switch self {
        case .trendingMovies: return "🔥 Hot Right Now"
        case .latestMovies: return "🎟️ In Theaters Now"
        case .popularMovies: return "Most Watched"
        case .upcomingMovies: return "Coming Soon"
            
        case .trendingSeries: return "🔥 Binge-Worthy Today"
        case .airingTodaySeries: return "Fresh Episodes"
        case .popularSeries: return "Most Watched"
        case .latestSeries: return "Critics' Choice"
        }
    }
    
    var isTopView: Bool {
        switch self {
        case .trendingMovies, .trendingSeries:
            return true
        default:
            return false
        }
    }
}

struct GenericResultResponse: Codable, Equatable {
    var results: [Result]
    var total_pages: Int?
    
    static func == (lhs: GenericResultResponse, rhs: GenericResultResponse) -> Bool {
        return lhs.results == rhs.results
    }
}

// MARK: - Result
struct Result: Codable, Hashable, Equatable {
    let backdrop_path: String?
    let first_air_date: String?
    let genre_ids: [Int]?
    let id: Int?
    let original_title: String?
    let name: String?
    let origin_country: [String]?
    let original_language, original_name, overview: String?
    let popularity: Double?
    let poster_path: String?
    let release_date: String?
    let title: String?
    let video: Bool?
    let vote_average: Double?
    let vote_count: Int?
    var media_type: String?
    let profile_path: String?
    let castID: Int?
    let runtime: Int?
    
    static func == (lhs: Result, rhs: Result) -> Bool {
        return lhs.id == rhs.id
    }
    
    func getResultTitle() -> String {
        return (name ?? title) ?? "- -"
    }
    
    func getResultPosterURL() -> URL {
        let posterURL = (poster_path ?? backdrop_path ?? profile_path) ?? ""
        return URL(string: API.Common.imageUrl(imageId: posterURL))
            ?? URL(string: API.baseURL)!
    }

    func getPosterURL() -> URL {
        let posterURL = poster_path ?? ""
        return URL(string: API.Common.imageUrl(imageId: posterURL))
            ?? URL(string: API.baseURL)!
    }

    func getBackdropURL() -> URL {
        let posterURL = backdrop_path ?? ""
        return URL(string: API.Common.imageUrl(imageId: posterURL))
            ?? URL(string: API.baseURL)!
    }
    
    func getMediaType() -> String {
        if media_type == "movie" {
            return "Movie"
        } else if media_type == "tv" {
            return "TV Series"
        } else {
            return "Actor"
        }
    }
    
    func getReleaseDate(addSeparator: Bool = true) -> String {
        
        if let date = release_date?.dropLast(6) {
            return date + (addSeparator ? " - " : "")
        } else if let date = first_air_date?.dropLast(6) {
            return date + (addSeparator ? " - " : "")
        } else {
            return ""
        }
    }
}
