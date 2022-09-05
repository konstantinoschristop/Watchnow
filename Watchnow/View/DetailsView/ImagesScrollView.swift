//
//  ImagesScrollView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 5/9/22.
//

import SwiftUI

struct ImagesScrollView: View {
    
    var results: [Images]?
    
    init(backdrops: [Images]?,
         posters: [Images]?) {
        
        self.results = []
        
        if let backdrops = backdrops {
            self.results?.append(contentsOf: backdrops)
        }
        if let posters = posters {
            self.results?.append(contentsOf: posters)
        }
    }
    
    var body: some View {
        
        if let results = results {
            
            ScrollView(.horizontal) {
                ForEach(results, id: \.self) { image in
                    if let imageURL = image.file_path,
                       let width = image.width,
                       let height = image.height {
                        
                        GenericImageView(url: APIKeys().imageKey + imageURL,
                                         width: CGFloat(integerLiteral: width),
                                         height: CGFloat(integerLiteral: height),
                                         cornerRadius: 10,
                                         showShadow: true)
                    }
                }
            }
        }
    }
}
