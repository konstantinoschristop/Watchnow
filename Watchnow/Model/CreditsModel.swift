//
//  CreditsModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 13/2/22.
//

import Foundation

struct CreditsModel: Codable {
    let id: Int?
    let cast, crew: [Cast]?
}

// MARK: - Cast
struct Cast: Codable, Hashable {
    let adult: Bool?
    let gender, id: Int?
    let name, original_name: String?
    let popularity: Double?
    let profile_path: String?
    let castID: Int?
    let character, credit_id: String?
    let order: Int?
    let job: String?
    let known_for: [Result]?
    
    func getName() -> String {
        
        return name ?? original_name ?? ""
    }
}
