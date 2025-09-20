//
//  BaseNetworkService.swift
//  Watchnow
//
//  Created by k.christopoulos on 20/9/25.
//

import Foundation

class BaseNetworkService {
    
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared, decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.decoder = decoder
    }

    // Common request method
    func request<T: Decodable>(urlString: String) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url)

        printJSON(for: url, and: data)
        
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        return try decoder.decode(T.self, from: data)
    }
    
    func printJSON(for url: URL?, and data: Data) {
        print("------ RESPONSE ------")
        print(String(describing: url))
        print(String(data: data, encoding: .utf8) as Any)
    }
}
