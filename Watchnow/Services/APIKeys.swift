//
//  APIKeys.swift
//  Watchnow
//
//  Created by k.christopoulos on 1/8/21.
//

import Foundation

enum API {
    static let key = "8a5d569103b429228d23a32db4b9a426"
    static let baseURL = "https://api.themoviedb.org/3"
    static let imageBaseURL = "https://image.tmdb.org/t/p/original/"
    static let youtubeBaseURL = "https://www.youtube.com/watch?v="
    static let language = "en-US"

    enum Common {
        static func credits(type: String, for id: String) -> String {
            return "\(API.baseURL)/\(type)/\(id)/credits?api_key=\(API.key)&language=\(API.language)"
        }
        static func similar(type: String, for id: String, page: Int = 1) -> String {
            return "\(API.baseURL)/\(type)/\(id)/similar?api_key=\(API.key)&language=\(API.language)&page=\(page)"
        }
        static func reviews(type: String, for id: String, page: Int = 1) -> String {
            return "\(API.baseURL)/\(type)/\(id)/reviews?api_key=\(API.key)&language=\(API.language)&page=\(page)"
        }
        static func videos(type: String, for id: String) -> String {
            return "\(API.baseURL)/\(type)/\(id)/videos?api_key=\(API.key)&language=\(API.language)"
        }
        static func season(tvId: Int, seasonNumber: Int) -> String {
            return "\(API.baseURL)/tv/\(tvId)/season/\(seasonNumber)?api_key=\(API.key)&language=\(API.language)"
        }
        static func person(id: Int) -> String {
            return "\(API.baseURL)/person/\(id)?api_key=\(API.key)&language=\(API.language)"
        }
        static func personCombinedCredits(id: Int) -> String {
            return "\(API.baseURL)/person/\(id)/combined_credits?api_key=\(API.key)&language=\(API.language)"
        }
        static func collection(id: Int) -> String {
            return "\(API.baseURL)/collection/\(id)?api_key=\(API.key)&language=\(API.language)"
        }
        static func watchProviders(type: String, id: String) -> String {
            return "\(API.baseURL)/\(type)/\(id)/watch/providers?api_key=\(API.key)"
        }

        /// Region-scoped catalogue of streaming services TMDB knows about,
        /// used to populate the "Browse by streaming service" tile row.
        static func providersList(type: String, region: String) -> String {
            return "\(API.baseURL)/watch/providers/\(type)?api_key=\(API.key)&language=\(API.language)&watch_region=\(region)"
        }

        /// Discover endpoint filtered to titles available on a specific
        /// streaming service in the user's region. `flatrate` restricts
        /// to subscription content (no rent / buy / ads).
        static func discoverByProvider(type: String, providerID: Int, region: String, page: Int = 1) -> String {
            return "\(API.baseURL)/discover/\(type)?api_key=\(API.key)&language=\(API.language)&watch_region=\(region)&with_watch_providers=\(providerID)&with_watch_monetization_types=flatrate&sort_by=popularity.desc&page=\(page)"
        }
        static func details(screenType: String, id: String) -> String {
            return "\(API.baseURL)/\(screenType)/\(id)?api_key=\(API.key)"
        }
        static func imageUrl(imageId: String) -> String {
            return API.imageBaseURL + imageId
        }
        static func youtubeUrl(videoId: String) -> String {
            return API.youtubeBaseURL + videoId
        }
    }

    enum Movie {
        static func popular(page: Int) -> String {
            return "\(API.baseURL)/movie/popular?api_key=\(API.key)&language=\(API.language)&page=\(page)"
        }
        static func upcoming(page: Int) -> String {
            return "\(API.baseURL)/movie/upcoming?api_key=\(API.key)&language=\(API.language)&page=\(page)"
        }
        static func trending(page: Int) -> String {
            return "\(API.baseURL)/trending/movie/day?api_key=\(API.key)&language=\(API.language)&page=\(page)"
        }
        static func nowPlaying(page: Int) -> String {
            return "\(API.baseURL)/movie/now_playing?api_key=\(API.key)&language=\(API.language)&page=\(page)"
        }
        /// `/discover/movie` sorted by weighted average with a 5 000-vote
        /// floor. TMDB's `/movie/top_rated` endpoint applies its own
        /// Bayesian filter but uses ~300 votes as the minimum, which lets
        /// niche titles with a handful of perfect ratings outrank genuine
        /// classics. Requiring 5 000 votes ensures only widely-seen,
        /// widely-rated films appear — Shawshank, The Godfather, etc.
        static func topRated(page: Int) -> String {
            return "\(API.baseURL)/discover/movie?api_key=\(API.key)&language=\(API.language)&sort_by=vote_average.desc&vote_count.gte=30000&page=\(page)"
        }
    }

    enum TV {
        static func popular(page: Int) -> String {
            return "\(API.baseURL)/tv/popular?api_key=\(API.key)&language=\(API.language)&page=\(page)"
        }
        static func airingToday(page: Int) -> String {
            return "\(API.baseURL)/tv/on_the_air?api_key=\(API.key)&language=\(API.language)&page=\(page)"
        }
        static func trending(page: Int) -> String {
            return "\(API.baseURL)/trending/tv/day?api_key=\(API.key)&language=\(API.language)&page=\(page)"
        }
        /// `/discover/tv` sorted by weighted average with a 1 000-vote
        /// floor. TV shows accumulate fewer votes than movies on TMDB, so
        /// 1 000 is the right threshold to filter out niche high-rated
        /// content while still surfacing Breaking Bad, Band of Brothers, etc.
        static func topRated(page: Int) -> String {
            return "\(API.baseURL)/discover/tv?api_key=\(API.key)&language=\(API.language)&sort_by=vote_average.desc&vote_count.gte=12000&page=\(page)"
        }
    }

    enum Search {
        static func multi(query: String, page: Int = 1) -> String {
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return "\(API.baseURL)/search/multi?api_key=\(API.key)&language=\(API.language)&include_adult=false&query=\(encodedQuery)&page=\(page)"
        }
    }

}
