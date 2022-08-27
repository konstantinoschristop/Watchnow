//
//  ContentDetailsView.swift
//  Watchnow
//
//  Created by k.christopoulos on 5/8/21.
//

import SwiftUI
import Kingfisher
import AlertToast
import FancyScrollView

enum ScreenTypes: String {
    case movie
    case tv
    case person
}

struct ContentDetailsView: View {
    
    var result: Result
    let screenType: ScreenTypes
    @StateObject private var detailsViewModel: DetailsViewModel
    @Environment(\.presentationMode) var presentation
    @State var showDetails = false
    @State private var showAlert = false
    
    init(result: Result, screenType: ScreenTypes) {
        _detailsViewModel = StateObject(wrappedValue: DetailsViewModel.init(service: ServiceInvaction.init(),
                                                                            screenType: screenType,
                                                                            id: String(describing: result.id!),
                                                                            result: result))
        self.screenType = screenType
        self.result = result
        self.result.media_type = screenType == .movie ? "movie" : "tv"
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
        
        if let availableGenres = detailsViewModel.details?.genres {
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
                .padding(.all, 15)
            }
        }
    }
    
    fileprivate func constructContent() -> some View {
        
        return VStack(spacing: 0) {
            ImageView(result: result,
                      detailsViewModel: detailsViewModel)

            Group {
                // scroll categories
                GenreView(ids: result.genre_ids)
                
                //DetailsView
                Details()
                
                // if series, show seasons and episodes
                if screenType == .tv {
                    if let seasons = detailsViewModel.details?.getSeasons(),
                       let numberOfSeasons = detailsViewModel.details?.number_of_seasons,
                       let numberOfEpisodes = detailsViewModel.details?.number_of_episodes,
                       let name = detailsViewModel.details?.name,
                       let seriesID = detailsViewModel.details?.id {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Seasons")
                                    .font(.system(size: 20, weight: .bold))
                                Spacer()
                            }
                            
                            HStack {
                                Text("Total Seasons: " + String(numberOfSeasons))
                                Divider()
                                Text("Total Episodes: " + String(numberOfEpisodes))
                                Spacer()
                                
                                NavigationLink("See all") {
                                    SeasonsDetailsTabView(seasons: seasons, navBarTitle: name, seriesID: seriesID)
                                }
                                .foregroundColor(.blue)
                                .padding(.trailing, 10)
                            }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.gray)
                        }
                        .padding(.top, 10)
                        .padding(.leading, 10)
                        SeasonsView(seasons: seasons, navBarTitle: name, seriesID: seriesID)
                    }
                }
                
                //cast
                if let cast = detailsViewModel.credits?.cast {
                    HStack {
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
                    VStack(spacing: 0) {
                        HStack {
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
        }
        .padding(.bottom, 50)
    }
    
    fileprivate func constructNavigationBar() -> NavigationBar {
        return NavigationBar(leftButtonIcon: "arrow.backward.circle.fill",
                             leftButtonAction: {
            self.presentation.wrappedValue.dismiss()
        },
                             rightButtonIcon: detailsViewModel.isInWatchList ?  "minus.circle.fill" : "plus.circle.fill",
                             rightButtonAction: {
            if detailsViewModel.isInWatchList {
                WatchlistManager.removeFromWatchList(result: result)
                detailsViewModel.isInWatchList = false
            } else {
                WatchlistManager.addToWatchList(result: result)
                detailsViewModel.isInWatchList = true
            }
            self.showAlert = true
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        },
                             title: detailsViewModel.imageHeight < 150 ? result.getResultTitle() : "",
                             opacity: detailsViewModel.imageHeight < 150 ? 1 : 0)
    }
    
    var body: some View {
        
        ZStack(alignment: .top) {
            if self.detailsViewModel.details != nil {
                ScrollView(.vertical, showsIndicators: false) {
                    self.constructContent()
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            GeometryReader { geometry in
                constructNavigationBar()
                    .frame(width: geometry.size.width,
                           height: 50 + geometry.safeAreaInsets.top)
                    .ignoresSafeArea()
            }
        }
        .navigationBarHidden(true)
        .toast(isPresenting: $showAlert, alert: {
            detailsViewModel.isInWatchList == false ?
            AlertToast(type: .systemImage("x.circle", .red), title: "Removed from Watchlist")  :
            AlertToast(type: .systemImage("checkmark.circle", .green), title: "Added to Watchlist")
        })
        .task {
            await detailsViewModel.getDetails()
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

