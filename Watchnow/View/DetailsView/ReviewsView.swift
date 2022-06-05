//
//  ReviewsView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 5/6/22.
//

import SwiftUI

struct ReviewsView: View {
    
    let reviews: [Reviews]
    @State var isPresented = false
    @State var selectedReview: Reviews?
    
    var body: some View {
        
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(reviews, id: \.self) { review in
                    HStack {
                        VStack {
                            if let imageUrl = review.author_details?.avatar_path,
                               imageUrl.contains("https") {
                                GenericImageView.init(url: imageUrl, width: 40, height: 40)
                                    .cornerRadius(30)
                                    .aspectRatio(contentMode: .fit)
                                    .shadow(color: .gray, radius: 5)
                            } else {
                                Image(systemName: "person")
                                    .resizable()
                                    .cornerRadius(20)
                                    .frame(width: 40, height: 40, alignment: .center)
                                    .aspectRatio(contentMode: .fit)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(review.author_details?.username ?? "- -")
                                
                                Spacer()
                                
                                if let rating = review.author_details?.rating {
                                    Text(Image(systemName: "star.fill"))
                                        .foregroundColor(.orange)
                                    + Text(" ") + Text(String(rating) + "/10")
                                }
                            }
                                .font(.system(size: 15, weight: .heavy))
                            Text(review.content ?? "- -")
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .onTapGesture {
                        self.selectedReview = review
                        self.isPresented.toggle()
                    }
                    .frame(width: 300, height: 70, alignment: .leading)
                }
            }
        }
        .sheet(isPresented: $isPresented) {
            ReviewSheet(review: self.$selectedReview)
        }
    }
}

struct ReviewSheet: View {
    
    @Binding var review: Reviews?
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                if let name = review?.author_details?.username {
                    Text("Review by " + name)
                }
                
                if let rating = review?.author_details?.rating {
                    Spacer()
                    
                    Text(Image(systemName: "star.fill"))
                        .foregroundColor(.orange)
                    + Text(" ") + Text(String(rating) + "/10")
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 30)
            .font(.system(size: 20, weight: .heavy))
            
            Text(review?.content ?? "- -")
                .font(.system(size: 15, weight: .medium))
            
            Spacer()
        }
        .padding()
    }
}
