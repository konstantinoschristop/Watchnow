//
//  BaseNetworkService.swift
//  Watchnow
//
//  Created by k.christopoulos on 20/9/25.
//

import Foundation

class BaseNetworkService: @unchecked Sendable {
    
    private let session: URLSession
    private let decoder: JSONDecoder

    /// Shared session with a timeout a person would actually wait out.
    ///
    /// `URLSession.shared` defaults to a 60-second request timeout, which is
    /// far too long for a fetch a screen is blocked on: the user taps, gets a
    /// placeholder, and has concluded the screen is broken long before the
    /// request gives up and the retryable error state appears. Twenty seconds
    /// is still generous for a slow cellular connection and turns a stall
    /// into something the UI can report.
    ///
    /// Also worth knowing: the default `httpMaximumConnectionsPerHost` is 6,
    /// and every TMDB call in the app goes to the same host. A screen that
    /// fans out eight requests at once is already queueing some of them, so a
    /// bounded timeout is what stops a queued request from stalling behind a
    /// slow one indefinitely.
    static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 40
        return URLSession(configuration: configuration)
    }()

    init(session: URLSession = BaseNetworkService.defaultSession,
         decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.decoder = decoder
    }

    // Common request method
    func request<T: Decodable>(urlString: String) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        return try decoder.decode(T.self, from: data)
    }
}
