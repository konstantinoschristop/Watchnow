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

struct ContentDetailsView: View {
    
    @StateObject var detailsViewModel: ContentDetailsViewModel
    @Environment(\.presentationMode) var presentation
    @State var showNavBar: Bool = false
    @State var videoPresented = false
    @State private var showAlert = false
    @State var isSheetPresented = false
    @State var isSeasonsSheetPresented = false
    @State var allSeasonsIndex: Int = 0
  
    var body: some View {
        
        ScrollView(.vertical, showsIndicators: false) {
            self.constructContent()
        }
        .overlay(alignment: .top, content: {
            if !showNavBar {
                navBarHiddenView
            }
        })
        .redacted(reason: detailsViewModel.viewModelFinishedFetching ? [] : .placeholder)
        .background(Color(.systemGray6))
        .navigationTitle(detailsViewModel.result.getResultTitle())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(!showNavBar)
        .navigationBarBackButtonHidden()
        .navigationBarItems(leading: navBarLeadingView,
                            trailing: navBarTrailingView)
        .toast(isPresenting: $showAlert, alert: {
            detailsViewModel.isInWatchList == false ?
            AlertToast(displayMode: .banner(.slide), type: .systemImage("x.circle", .red), title: "Removed from Watchlist")  :
            AlertToast(displayMode: .banner(.slide), type: .systemImage("checkmark.circle", .green), title: "Added to Watchlist")
        })
        .sheet(isPresented: $videoPresented) {
            WebView(videoURL: detailsViewModel.videos?.getVideoURL())
                .ignoresSafeArea()
        }
        .task {
            await detailsViewModel.getDetails()
            await detailsViewModel.getCredits()
            await detailsViewModel.getVideos()
            await detailsViewModel.getWatchProviders()
            await detailsViewModel.getSimilars()
            await detailsViewModel.getReviews()
            await detailsViewModel.getCollection()
        }
    }
}

extension ContentDetailsView {
    
    fileprivate func constructContent() -> some View {
        
        let result = detailsViewModel.result
        let screenType = detailsViewModel.screenType
        
        return VStack(spacing: 0) {
            MenuFeaturedView(content: result,
                             overlayContent: overlayContent(for: result),
                             showNavBar: $showNavBar)

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
                
                // Watch Providers
                if let watchProvidersResults = detailsViewModel.watchProviders?.results,
                   let watchProvider = watchProvidersResults[Locale.current.language.region?.identifier ?? "US"],
                   watchProvider.flatrate?.isEmpty == false || watchProvider.rent?.isEmpty == false {
                    
                    HStack {
                        Text("Available on")
                            .font(.system(size: 20, weight: .bold))
                        Spacer()
                    }
                    .padding(.top, 10)
                    .padding(.leading, 10)
                    
                    WatchProviderView(flatrates: watchProvider.flatrate ?? [],
                                      rent: watchProvider.rent ?? [])
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
                
                //                AdBannerView()
                //                    .frame(height: 50)
                //                    .padding(.bottom)
            }
        }
        .padding(.bottom, 50)
    }
    
    @ViewBuilder
    func overlayContent(for content: Result) -> some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [.clear,
                                    .black.opacity(0.6)],
                           startPoint: .center,
                           endPoint: .bottom)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(content.getResultTitle())
                        .font(.custom("AvenirNext-Bold", size: 25))
                        .foregroundColor(.white)
                    Spacer()
                    
                    if detailsViewModel.videos?.getVideoURL() != nil {
                        VStack {
                            Button(action: {
                                videoPresented.toggle()
                            }) {
                                Image(systemName: "play.fill")
                                    .imageScale(SwiftUI.Image.Scale.large)
                                    .foregroundColor(.red)
                            }
                            Spacer()
                                .frame(height: 12)
                            Text("Watch Trailer")
                                .font(.custom("AvenirNext-Bold", size: 12))
                                .foregroundColor(.white)
                        }
                    }
                }
                .shadow(color: .black, radius: 3)
            }
            .padding(.horizontal)
            .padding(.bottom, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
           
        }
        .blur(radius: showNavBar ? 10 : 0)
    }
    
    var navBarLeadingView: some View {
        
        getNavBarButton(imageName: "arrow.backward.circle.fill") {
            self.presentation.wrappedValue.dismiss()
        }
    }
    
    var navBarTrailingView: some View {
        
        HStack(spacing: 20) {
            getNavBarButton(imageName: detailsViewModel.isInWatchList ?  "minus.circle.fill" : "plus.circle.fill") {
                if detailsViewModel.isInWatchList {
                    WatchlistManager.removeFromWatchList(result: detailsViewModel.result)
                    detailsViewModel.isInWatchList = false
                } else {
                    WatchlistManager.addToWatchList(result: detailsViewModel.result)
                    detailsViewModel.isInWatchList = true
                }
                self.showAlert = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            
            getNavBarButton(imageName: "square.and.arrow.up.circle.fill") {
                let shareActivity = UIActivityViewController(activityItems: [URL(string: detailsViewModel.createShareLink())],
                                                             applicationActivities: nil)
                
                if let vc = UIApplication.shared.windows.first?.rootViewController {
                    shareActivity.popoverPresentationController?.sourceView = vc.view
                    shareActivity.popoverPresentationController?.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2,
                                                                                     y: UIScreen.main.bounds.height, width: 0, height: 0)
                    
                    shareActivity.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection.down
                    vc.present(shareActivity, animated: true, completion: nil)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
        }
    }
    
    private func getNavBarButton(imageName: String,
                                 action: @escaping () -> Void) -> some View{
        
        Button(action: action,
               label: {
            Image(systemName: imageName)
                .resizable()
                .frame(width: 25, height: 25)
                .foregroundColor(.white)
                .shadow(color: .black, radius: 3)
        })
    }
    
    var navBarHiddenView: some View {
        HStack {
            navBarLeadingView
            Spacer()
            navBarTrailingView
        }
        .padding()
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

