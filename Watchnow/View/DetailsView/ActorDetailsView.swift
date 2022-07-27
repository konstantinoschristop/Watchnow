//
//  ActorDetailsView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 27/7/22.
//

import SwiftUI

struct ActorDetailsView: View {
    
    var actorID: Int?
    
    var body: some View {
        Text(String(actorID ?? 0))
    }
}


