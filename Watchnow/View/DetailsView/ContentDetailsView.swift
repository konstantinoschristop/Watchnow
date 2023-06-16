//
//  ContentDetailsView.swift
//  Watchnow
//
//  Created by k.christopoulos on 5/8/21.
//

import SwiftUI
import Kingfisher
import AlertToast
import PartialSheet

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
    @State var isSheetPresented = false
    @State var isSeasonsSheetPresented = false
    @State var allSeasonsIndex: Int = 0
    
    init(result: Result, screenType: ScreenTypes) {
        _detailsViewModel = StateObject(wrappedValue: DetailsViewModel.init(service: ServiceInvocation.init(),
                                                                            screenType: screenType,
                                                                            id: String(describing: result.id!),
                                                                            result: result))
        self.screenType = screenType
        self.result = result
        self.result.media_type = screenType == .movie ? "movie" : "tv"
    }
  
    var body: some View {
        
        Group {
            if detailsViewModel.viewModelFinishedFetching {
                ZStack(alignment: .top) {
                    ScrollView(.vertical, showsIndicators: false) {
                       self.constructContent()
                    }
                    GeometryReader { geometry in
                        constructNavigationBar()
                            .frame(width: geometry.size.width,
                                   height: 45 + geometry.safeAreaInsets.top)
                            .ignoresSafeArea()
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(.systemGray6))
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
            await detailsViewModel.getCollection()
        }
    }
}

extension ContentDetailsView {
    
    fileprivate func constructContent() -> some View {
        
        return VStack(spacing: 0) {
            ImageView(result: result,
                      detailsViewModel: detailsViewModel)

            Group {
                // scroll categories
                if let availableGenres = detailsViewModel.details?.genres,
                   availableGenres.isEmpty == false {
                    
                    GenresView(genres: availableGenres)
                }
    
                //DetailsView
                DetailsView(details: detailsViewModel.details)
                
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
                                
                                Button {
                                    isSeasonsSheetPresented.toggle()
                                } label: {
                                    Text("See all")
                                        .foregroundColor(.blue)
                                }
                            }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.gray)
                        }
                        .padding(.all, 10)
                        SeasonsView(seasons: seasons, navBarTitle: name, seriesID: seriesID)
                            .sheet(isPresented: $isSeasonsSheetPresented) {
                                SeasonsDetailsTabView(index: $allSeasonsIndex,
                                                      seasons: seasons,
                                                      navBarTitle: name,
                                                      seriesID: seriesID)
                                    .presentationDetents([.medium, .large])
                            }
                    }
                }
                
                //cast
                if let cast = detailsViewModel.credits?.cast,
                   cast.isEmpty == false {
                    
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
                if let content = detailsViewModel.similar?.results,
                   content.isEmpty == false {
                    
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
                        .padding(.bottom, -30)
                }
                // user reviews
                if let reviews = detailsViewModel.reviews?.results,
                   reviews.isEmpty == false {
                    
                    HStack {
                        Text("User Reviews")
                            .font(.system(size: 20, weight: .bold))
                        Spacer()
                    }
                    .padding(.top, 10)
                    .padding(.leading, 10)
                    ReviewsView(reviews: reviews)
                }
                
                // Additional Info
                if let details = detailsViewModel.details {
                    
                    HStack {
                        Text("Additional Information")
                            .font(.system(size: 20, weight: .bold))
                        Spacer()
                    }
                    .padding(.top, 10)
                    .padding(.leading, 10)
                    AdditionalInfoView(details: details)
                }
                
                // collection
                if let collection = detailsViewModel.details?.belongs_to_collection,
                   let collectionName = collection.name,
                   let content = detailsViewModel.collection?.parts,
                   content.isEmpty == false {
                    
                    VStack(spacing: 0) {
                        HStack() {
                            Text("Belongs to: " + collectionName)
                                .font(.system(size: 20, weight: .bold))
                            Spacer()
                        }
                        HStack {
                            Text("Parts of the Collection")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.gray)
                            Spacer()
                        }
                    }
                    .padding(.top, 10)
                    .padding(.leading, 10)
                    SimilarsView(content: content, screenType: screenType)
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
}

extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = nil
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }
}

