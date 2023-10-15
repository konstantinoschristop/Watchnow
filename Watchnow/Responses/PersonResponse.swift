//
//  PersonResponse.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 16/8/22.
//

import Foundation
 
struct PersonResponse: Codable {
    
    var birthday: String?
    var deathday: String?
    var id: Int?
    var name: String?
    var gender: Int?
    var biography: String?
    var popularity: Double?
    var place_of_birth: String?
    var profile_path: String?
}
