//
//  UpcomingMoviesModel.swift
//  Watchnow
//
//  Created by k.christopoulos on 1/8/21.
//

import Foundation
import SwiftUI

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

    /// Emoji-prefixed title kept for any legacy caller. New layouts use
    /// `cleanTitle` + `themeIcon` so the icon is a proper SF Symbol that
    /// can be tinted, animated, and styled consistently.
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

    /// Emoji-free variant. The emoji is replaced by a tinted SF Symbol
    /// rendered alongside the title in `SectionHeaderView`, which gives
    /// us a proper tint, a larger hit-size, and the option to animate
    /// the glyph (e.g. the live pulse on trending).
    var cleanTitle: String {
        switch self {
        case .trendingMovies: return "Hot Right Now"
        case .latestMovies: return "In Theaters Now"
        case .popularMovies, .popularSeries: return "Most Watched"
        case .upcomingMovies: return "Coming Soon"
        case .trendingSeries: return "Binge-Worthy Today"
        case .airingTodaySeries: return "Fresh Episodes"
        case .latestSeries: return "Critics' Choice"
        }
    }

    /// Section-specific SF Symbol. Rendered at the leading edge of the
    /// header; carries the section's personality without bloating the
    /// title with emoji.
    var themeIcon: String {
        switch self {
        case .trendingMovies, .trendingSeries: return "flame.fill"
        case .latestMovies:                    return "ticket.fill"
        case .popularMovies, .popularSeries:   return "eye.fill"
        case .upcomingMovies:                  return "calendar"
        case .airingTodaySeries:               return "sparkles"
        case .latestSeries:                    return "star.circle.fill"
        }
    }

    /// Tint applied to both the header's 3pt rail and the section icon.
    /// Colours were picked so each section feels distinct without
    /// clashing when two sections stack vertically.
    var themeColor: Color {
        switch self {
        case .trendingMovies, .trendingSeries: return .red
        case .latestMovies:                    return .orange
        case .popularMovies, .popularSeries:   return .accentColor
        case .upcomingMovies:                  return .blue
        case .airingTodaySeries:               return .green
        case .latestSeries:                    return .purple
        }
    }

    /// Trending sections show a small live-pulse dot so the row reads
    /// as real-time, not canned.
    var isTrending: Bool {
        switch self {
        case .trendingMovies, .trendingSeries: return true
        default: return false
        }
    }

    var isTopView: Bool { isTrending }
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
