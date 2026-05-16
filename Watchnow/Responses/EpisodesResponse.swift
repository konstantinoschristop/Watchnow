//
//  EpisodesResponse.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 15/8/22.
//

import Foundation

struct EpisodesResponse: Codable {
    
    var episodes: [Episode]?
    var air_date: String?
}

struct Episode: Codable, Hashable {

    let id: Int?
    let name: String?
    let overview: String?
    let still_path: String?
    let vote_average: Double?
    let vote_count: Int?
    let air_date: String?
    let episode_number: Int?

    /// Parses `air_date` (yyyy-MM-dd) into a `Date`. Returns nil when the
    /// field is missing or unparseable.
    func airDateValue() -> Date? {
        guard let raw = air_date, !raw.isEmpty else { return nil }
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .iso8601)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.date(from: raw)
    }
}
