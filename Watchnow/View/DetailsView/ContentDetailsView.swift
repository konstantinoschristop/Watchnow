//
//  ContentDetailsView.swift
//  Watchnow
//
//  Created by k.christopoulos on 5/8/21.
//

import SwiftUI
import Kingfisher

enum ScreenTypes: String {
    case movie
    case tv
}

struct ContentDetailsView: View {
    
    let result: Result
    let screenType: ScreenTypes
    @StateObject private var creditsVM: CreditsViewModel
    @StateObject private var similarsVM: GetSimilarViewModel
    @StateObject private var reviewsVM: ReviewsViewModel
    
    @Environment(\.presentationMode) var presentation
    @State var showDetails = false
    
    init(result: Result, screenType: ScreenTypes) {
        self.screenType = screenType
        self.result = result
        _creditsVM = StateObject(wrappedValue: CreditsViewModel.init(service: ServiceInvaction.init(), screenType: screenType, id: String(describing: result.id!)))
        _similarsVM = StateObject(wrappedValue: GetSimilarViewModel.init(service: ServiceInvaction(), screenType: screenType, id: String(describing: result.id!)))
        _reviewsVM = StateObject(wrappedValue: ReviewsViewModel.init(service: ServiceInvaction(), screenType: screenType, id: String(describing: result.id!)))
    }
    
    @ViewBuilder
    func Details() -> some View {
        VStack(alignment: .center) {
            ZStack {
                VStack {
                    if let overview = result.overview {
                        Text(overview)
                    }
                    Spacer()
                        .frame(height: 20)
                    HStack {
                        if let rating = result.vote_average {
                            Image(systemName: "star.fill")
                                .foregroundColor(.orange)
                            Text(String(format: "%.1f", rating) + "/10")
                        }
                        if let allRatings = result.vote_count {
                            Text("• " + String(allRatings) + " ratings")
                        }
                        if let releaseData = result.release_date?.dropLast(6) {
                            Text("• Release Date: " + releaseData)
                        }
                    }
                    .font(.custom("AvenirNext-Regular", size: 15))
                    .foregroundColor(.gray)
                }
            }
        }
        .padding(.init(top: 0, leading: 20, bottom: 0, trailing: 20))
    }
    
    var body: some View {
                    
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ImageView(result: result)
                }
                VStack {
                    
                    // scroll categories
                    
                    // if series, show seasons and episodes
                    
                    Details()
                    
                    // trailer
                    
                    //cast
                    if let cast = creditsVM.credits?.cast {
                        HStack{
                            Text("Cast")
                                .font(.system(size: 20, weight: .bold))
                            Spacer()
                        }
                        .padding(.top, 10)
                        .padding(.leading, 10)
                        CastView(cast: cast)
                    }
                   
                    // similar
                    if let content = similarsVM.similar?.results {
                        VStack {
                            HStack{
                                Text(screenType == .movie ? "Similar Movies" : "Similar TV Shows")
                                    .font(.system(size: 20, weight: .bold))
                                Spacer()
                            }
                            HStack {
                                Text("You might also like")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                        }
                        .padding(.top, 10)
                        .padding(.leading, 10)
                        SimilarsView(content: content, screenType: screenType)
                    }
                    // user reviews
                    if let reviews = reviewsVM.reviews?.results,
                       reviews.isEmpty == false {
                        HStack{
                            Text("User Reviews")
                                .font(.system(size: 20, weight: .bold))
                            Spacer()
                        }
                        .padding(.top, -10)
                        .padding(.leading, 10)
                        ReviewsView(reviews: reviews)
                    }
                }
                .padding(.top, 25)
                .padding(.bottom, 100)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(leading: Button(action : {
                self.presentation.wrappedValue.dismiss()
            }){
                Image(systemName: "arrow.backward.circle.fill")
                    .resizable()
                    .frame(width: 25, height: 25)
                    .foregroundColor(.gray)
            })
        .task {
            await creditsVM.getCredits()
            await similarsVM.getSimilars()
            await reviewsVM.getReviews()
        }
    }
}

extension UINavigationController {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = nil
    }
}
