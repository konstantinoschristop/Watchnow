//
//  TrailerButton.swift
//  Watchnow
//
//  Created by k.christopoulos on 30/11/25.
//

import SwiftUI

struct TrailerButton: View {
    @Binding var videoPresented: Bool

    var body: some View {
        VStack {
            Button {
                videoPresented.toggle()
            } label: {
                Image(systemName: "play.fill")
                    .imageScale(.large)
                    .foregroundColor(.red)
            }
            Spacer().frame(height: 12)
            Text("Watch Trailer")
                .font(.custom("AvenirNext-Bold", size: 12))
                .foregroundColor(.white)
        }
    }
}
