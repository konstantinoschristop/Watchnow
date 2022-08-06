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
    case person
}

struct ContentDetailsView: View {
    
    let result: Result
    let screenType: ScreenTypes
    @StateObject private var detailsViewModel: DetailsViewModel
    
    @Environment(\.presentationMode) var presentation
    @State var showDetails = false
    
    init(result: Result, screenType: ScreenTypes) {
        self.screenType = screenType
        self.result = result
        _detailsViewModel = StateObject(wrappedValue: DetailsViewModel.init(service: ServiceInvaction.init(),
                                                                            screenType: screenType,
                                                                            id: String(describing: result.id!)))
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
                        Text("• Release Date: " + result.getReleaseDate(addSeparator: false))
                    }
                    .font(.custom("AvenirNext-Regular", size: 15))
                    .foregroundColor(.gray)
                }
            }
        }
        .padding(.init(top: 0, leading: 20, bottom: 0, trailing: 20))
    }
    
    @ViewBuilder
    func GenreView(ids: [Int]?) -> some View {
        
        if let availableGenres = detailsViewModel.genres?.getAvailableGenres(ids: ids) {
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(availableGenres, id: \.self) { genre in
                        Text(genre.name ?? "- -")
                            .padding()
                            .font(.system(size: 11))
                            .background(Color(.systemGray5))
                            .cornerRadius(20)
                    }
                }
                .padding(.init(top: 0, leading: 20, bottom: 10, trailing: 20))
            }
        }
    }
    
    @ViewBuilder
    func SeasonsView() -> some View {
    }
    
    var body: some View {
        
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ImageView(result: result,
                          detailsViewModel: detailsViewModel)
            }
            VStack {
                // scroll categories
                GenreView(ids: result.genre_ids)
                
                // if series, show seasons and episodes
                if screenType == .tv {
                    SeasonsView()
                }
                
                //DetailsView
                Details()
                
                //cast
                if let cast = detailsViewModel.credits?.cast {
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
                if let content = detailsViewModel.similar?.results {
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
                if let reviews = detailsViewModel.reviews?.results,
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
        .background(Color(.systemGray6))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Button(action : {
            self.presentation.wrappedValue.dismiss()
        }){
            Image(systemName: "arrow.backward.circle.fill")
                .resizable()
                .frame(width: 25, height: 25)
                .foregroundColor(.white)
                .shadow(color: .black, radius: 3)
        },
                            trailing: Button(action : {
           
        }){
            Image(systemName: "star.circle.fill")
                .resizable()
                .frame(width: 25, height: 25)
                .foregroundColor(.orange)
                .shadow(color: .black, radius: 3)
        })
        
        .task {
            await detailsViewModel.getGenres(screenType: self.screenType)
            await detailsViewModel.getCredits()
            await detailsViewModel.getVideos()
            await detailsViewModel.getSimilars()
            await detailsViewModel.getReviews()
        }
    }
}

extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }
}

