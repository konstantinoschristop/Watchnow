//
//  SearchModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 10/7/22.
//

import Foundation
import SwiftUI

struct SearchModel: Codable {
    var results: [Result]?
}

enum GendreIDs: Int, CaseIterable {
    
    case comedy = 35
    case crime = 80
    case drama = 18
    case family = 10751
    case mystery = 9648
    case animation = 16
    
    func getNameForGenre() -> String {
    
        switch self {
        case .comedy:
             return "Comedy"
        case .crime:
            return "Crime"
        case .drama:
            return "Drama"
        case .family:
            return "Family"
        case .mystery:
            return "Mystery"
        case .animation:
            return "Animation"
        }
    }
    
    func getBackgroundColorForGenre() -> Color {
    
        switch self {
        case .comedy:
             return .orange
        case .crime:
            return .brown
        case .drama:
            return .gray
        case .family:
            return .blue
        case .mystery:
            return .red
        case .animation:
            return .yellow
        }
    }
}
