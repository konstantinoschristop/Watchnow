//
//  ImagesModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 5/9/22.
//

import Foundation

struct ImagesModel: Codable, Hashable {
    
    let backdrops: [Images]?
    let posters: [Images]?
}

struct Images: Codable, Hashable {
    
    let file_path: String?
    let width: Int?
    let height: Int?
}
