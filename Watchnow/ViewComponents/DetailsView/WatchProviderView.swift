//
//  WatchProviderView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 1/8/23.
//

import SwiftUI

struct WatchProviderView: View {
    
    let flatrates: [Flatrate]
    let rent: [Flatrate]
    
    var body: some View {
        
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(flatrates, id: \.providerID) { flatrate in
                    getProviderView(flatrate,
                                    availableFor: "Stream")
                }
                
                ForEach(rent, id: \.providerID) { thisRent in
                    getProviderView(thisRent,
                                    availableFor: "Rent")
                }
            }
            .padding(10)
        }
        
        Text("Streaming information provided by JustWatch")
            .font(.system(size: 8, weight: .light))
            .italic()
    }
    
    @ViewBuilder
    func getProviderView(_ content: Flatrate,
                         availableFor: String) -> some View {
        if let imageURL = content.logoPath,
           let name = content.providerName  {
            
            let url = API.Common.imageUrl(imageId: imageURL)
            
            VStack(alignment: .center) {
                GenericImageView.init(url: url,
                                      width: 50,
                                      height: 50,
                                      cornerRadius: 6,
                                      showShadow: true)
                .clipShape(Circle())
                    Text(name)
                        .font(.system(size: 12, weight: .heavy))
                        .multilineTextAlignment(.center)
                        .frame(width: 80, height: 30)
                    Text(availableFor)
                        .font(.system(size: 12, weight: .regular))
                        .multilineTextAlignment(.center)
            }
        }
    }
}

