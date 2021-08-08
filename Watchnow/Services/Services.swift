//
//  Services.swift
//  Watchnow
//
//  Created by k.christopoulos on 1/8/21.
//

import Foundation
import SwiftUI

class Services: ObservableObject {
    
    let api = APIKeys()
    
    //MARK: - Movies API
    
    func fetchUpcomingMovies(completion: @escaping (UpcomingMoviesViewModel?) -> ()) {
        
        guard let url = URL(string: api.upcomingMovies) else {
            return
        }
        
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let safeData = data {
                do {
                    let decodedData = try JSONDecoder().decode(UpcomingMoviesModel.self, from: safeData)
                    
                    let upcoming = UpcomingMoviesViewModel.init(dataModel: decodedData)
                    completion(upcoming)
                } catch {
                    completion(nil)
                }
            }
        }.resume()
    }
    
    func fetchPopularMovies(completion: @escaping (PopularMoviesViewModel?) -> ()) {
        
        guard let url = URL(string: api.popularMovies) else {
            return
        }
        
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let safeData = data {
                do {
                    let decodedData = try JSONDecoder().decode(PopularMoviesModel.self, from: safeData)
                    
                    let popular = PopularMoviesViewModel.init(dataModel: decodedData)
                    completion(popular)
                } catch {
                    completion(nil)
                }
            }
        }.resume()
    }
    
    func fetchMovieGenres(completion: @escaping (MovieGenresViewModel?) -> ()) {
        
        guard let url = URL(string: api.movieGenres) else {
            return
        }
        
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let safeData = data {
                do {
                    let decodedData = try JSONDecoder().decode(MovieGenresModel.self, from: safeData)
                    
                    let genres = MovieGenresViewModel.init(dataModel: decodedData)
                    completion(genres)
                } catch {
                    completion(nil)
                }
            }
        }.resume()
    }
    
    func fetchMovieDetails(movieID: String, completion: @escaping (MovieDetailsViewModel?) -> ()) {
        
        let detailsUrl = api.movieDetails + movieID + api.apikey
        guard let url = URL(string: detailsUrl) else {
            return
        }
        
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let safeData = data {
                do {
                    let decodedData = try JSONDecoder().decode(MovieDetailsModel.self, from: safeData)
                    
                    let details = MovieDetailsViewModel.init(dataModel: decodedData)
                    completion(details)
                } catch {
                    completion(nil)
                }
            }
        }.resume()
    }
    
    func fetchSimilarMovies(movieID: String, completion: @escaping (SimilarMoviesViewModel?) -> ()) {
        
        let similarUrl = api.movieDetails + movieID + "/similar" + api.apikey
        guard let url = URL(string: similarUrl) else {
            return
        }
        
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let safeData = data {
                do {
                    let decodedData = try JSONDecoder().decode(SimilarMoviesModel.self, from: safeData)
                    
                    let similar = SimilarMoviesViewModel.init(dataModel: decodedData)
                    completion(similar)
                } catch {
                    completion(nil)
                }
            }
        }.resume()
    }
}
