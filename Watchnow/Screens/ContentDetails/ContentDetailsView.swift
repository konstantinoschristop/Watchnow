//
//  ContentDetailsView.swift
//  Watchnow
//
//  Created by k.christopoulos on 5/8/21.
//

import SwiftUI
import Kingfisher
import AlertToast
import TipKit

struct ContentDetailsView: View {
    
    @StateObject var detailsViewModel: ContentDetailsViewModel
    @Environment(\.dismiss) var dismiss
    @State var videoPresented = false
    @State private var showAlert = false
    @State var isSheetPresented = false
    @State var isSeasonsSheetPresented = false
    @Namespace private var namespace
    
    var body: some View {
        
        ScrollView(.vertical, showsIndicators: false) {
            self.constructContent()
        }
        .ignoresSafeArea(edges: .top)
        .redacted(reason: detailsViewModel.viewModelFinishedFetching ? [] : .placeholder)
        .background(Color(.background))
        .navigationBarTitleDisplayMode(.inline)
        .hideBackButtonOptionally()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { navBarLeadingView }
            ToolbarItem(placement: .navigationBarTrailing) { navBarTrailingView }
        }
        .toast(isPresenting: $showAlert, alert: {
            detailsViewModel.isInWatchList == false ?
            AlertToast(displayMode: .hud, type: .systemImage("x.circle", .red), title: "Removed from Watchlist")  :
            AlertToast(displayMode: .hud, type: .systemImage("checkmark.circle", .green), title: "Added to Watchlist")
        })
        .sheet(isPresented: $videoPresented) {
            WebView(videoURL: detailsViewModel.videos?.getVideoURL())
                .ignoresSafeArea()
        }
        .task {
            // getDetails must complete first — getCollection reads details?.belongs_to_collection
            await detailsViewModel.getDetails()

            async let credits: Void = detailsViewModel.getCredits()
            async let videos: Void = detailsViewModel.getVideos()
            async let providers: Void = detailsViewModel.getWatchProviders()
            async let similars: Void = detailsViewModel.getSimilars()
            async let reviews: Void = detailsViewModel.getReviews()
            async let collection: Void = detailsViewModel.getCollection()
            _ = await (credits, videos, providers, similars, reviews, collection)
        }
    }
}

extension ContentDetailsView {
    
    fileprivate func constructContent() -> some View {
        
        let result = detailsViewModel.result
        let screenType = detailsViewModel.screenType
        
        return VStack(spacing: 10) {
    
            MenuFeaturedView(results: [result],
                             overlayContent: { _ in overlayContent(for: result) },
                             screenType: screenType,
                             showNavBar: .constant(true))
            
            genresSection()
            detailsSection()
            seasonsSection()
            watchProvidersSection()
            castSection()
            similarsSection()
            reviewsSection()
            additionalInfoSection()
            collectionSection()
        }
        .padding(.bottom, 50)
    }
    
    // MARK: - Overlay
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
                        TrailerButton(videoPresented: $videoPresented)
                    }
                }
                .shadow(color: .black, radius: 3)
            }
            .padding(.horizontal)
            .padding(.bottom, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
           
        }
    }
    
    // MARK: - Navigation Bar
    @ViewBuilder
    var navBarLeadingView: some View {
        
        if #unavailable(iOS 26) {
            getNavBarButton(imageName: "arrow.backward") {
                self.dismiss()
            }
        }
    }
    
    var navBarTrailingView: some View {
        
        HStack(alignment: .center, spacing: 20) {
            getNavBarButton(imageName: detailsViewModel.isInWatchList ?  "text.badge.minus" : "text.badge.plus") {
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
            
            if let url = URL(string: detailsViewModel.createShareLink()) {
                ShareLink(item: url) {
                    getnavBarLabel(imageName: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 5)
    }
    
    @ViewBuilder
    private func getNavBarButton(imageName: String,
                                 action: @escaping () -> Void) -> some View{
        
        Button(action: action,
               label: { getnavBarLabel(imageName: imageName)} )
    }
    
    @ViewBuilder
    private func getnavBarLabel(imageName: String) -> some View {
        if #available(iOS 26.0, *) {
            Image(systemName: imageName)
        } else {
            Image(systemName: imageName)
                .foregroundColor(.white)
                .shadow(color: .black, radius: 3)
                .bold()
        }
    }
    
}

// MARK: - Sections
extension ContentDetailsView {
    @ViewBuilder
    private func genresSection() -> some View {
        if detailsViewModel.hasGenres {
            GenresView(genres: detailsViewModel.genresSafe)
        }
    }

    @ViewBuilder
    private func detailsSection() -> some View {
        DetailsView(details: detailsViewModel.details)
    }

    @ViewBuilder
    private func seasonsSection() -> some View {
        let screenType = detailsViewModel.screenType
        if screenType == .tv, detailsViewModel.hasSeasons {
            let seasons = detailsViewModel.seasonsSafe
            let numberOfSeasons = detailsViewModel.details?.number_of_seasons ?? 0
            let numberOfEpisodes = detailsViewModel.details?.number_of_episodes ?? 0
            let name = detailsViewModel.details?.name ?? ""
            let seriesID = detailsViewModel.details?.id ?? 0

            HStack(alignment: .bottom) {
                SectionHeaderView(title: "Seasons",
                                  subtitle: "\(numberOfSeasons) Seasons | \(numberOfEpisodes) Episodes")
                
                Button {
                    isSeasonsSheetPresented.toggle()
                } label: {
                    Text("See all")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal)
                }
            }

            SeasonsView(seasons: seasons, navBarTitle: name, seriesID: seriesID)
                .sheet(isPresented: $isSeasonsSheetPresented) {
                    SeasonsDetailsTabView(
                        seasons: seasons,
                        selectedSeason: $detailsViewModel.selectedSeason,
                        seriesID: seriesID
                    )
                    .presentationDetents([.large])
                }
        }
    }

    @ViewBuilder
    private func watchProvidersSection() -> some View {
        if detailsViewModel.hasWatchProviders,
           let provider = detailsViewModel.watchProviderSafe {

            SectionHeaderView(title: "Available on")

            WatchProviderView(
                flatrates: provider.flatrate ?? [],
                rent: provider.rent ?? []
            )
        }
    }

    @ViewBuilder
    private func castSection() -> some View {
        if detailsViewModel.hasCast {
            CastView(cast: detailsViewModel.castSafe)
        }
    }

    @ViewBuilder
    private func similarsSection() -> some View {
        let screenType = detailsViewModel.screenType
        if detailsViewModel.hasSimilars {
            let content = detailsViewModel.similarsSafe

            SectionHeaderView(title: "Similar \(screenType.rawValue)",
                              subtitle: "You might also like")

            SimilarsView(content: content, screenType: screenType, namespace: namespace)
                .padding(.bottom, -30)
        }
    }

    @ViewBuilder
    private func reviewsSection() -> some View {
        if detailsViewModel.hasReviews {
            let reviews = detailsViewModel.reviewsSafe

            SectionHeaderView(title: "User Reviews")

            ReviewsView(reviews: reviews)
        }
    }

    @ViewBuilder
    private func additionalInfoSection() -> some View {
        if let details = detailsViewModel.details {

            SectionHeaderView(title: "Additional Information")

            AdditionalInfoView(details: details)
        }
    }

    @ViewBuilder
    private func collectionSection() -> some View {
        let screenType = detailsViewModel.screenType
        if detailsViewModel.hasCollection,
           let collectionName = detailsViewModel.details?.belongs_to_collection?.name {
            let content = detailsViewModel.collectionSafe

            SectionHeaderView(title: "Belongs to: \(collectionName)",
                              subtitle: "Parts of the Collection")

            SimilarsView(content: content, screenType: screenType, namespace: namespace)
        }
    }
}
