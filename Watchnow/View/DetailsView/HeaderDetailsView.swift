//
//  HeaderDetailsView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 2/3/22.
//

import SwiftUI

struct HeaderDetailsView: View {
    
    @State var show = false
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                let y = geometry.frame(in: .global).minY + UIScreen.main.bounds.height / 2
                Group {
                    Rectangle()
                        .frame(height: 80)
                        .background(.ultraThinMaterial)
                    Text("hi")
                }
                .onAppear {
                    show = y < 0 ? true : false
                }
            }
        }
        .opacity(show ? 1 : 0)
           
        //.padding([.horizontal, .bottom])
    }
}

struct HeaderDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        HeaderDetailsView()
    }
}
