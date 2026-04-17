//
//  ContentDetailsView.swift
//  Watchnow
//
//  Created by k.christopoulos on 5/8/21.
//

import SwiftUI
import Kingfisher
import AlertToast

struct ContentDetailsView: View {

    @StateObject var detailsViewModel: ContentDetailsViewModel
    @Environment(\.dismiss) var dismiss
    @State var videoPresented = false
    @State private var showAlert = false
    @State var isSeasonsSheetPresented = false
    @State private var isWatchNowPresented = false
    @Namespace private var namespace

    var body: some View {

        Group {
            if detailsViewModel.apiError && !detailsViewModel.viewModelFinishedFetching {
                ContentUnavailableView("Couldn't load content",
                                       systemImage: "exclamationmark.triangle",
                                       description: Text("Check your connection and try again."))
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    self.constructContent()
                }
                .redacted(reason: detailsViewModel.viewModelFinishedFetching ? [] : .placeholder)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color(.background))
        .navigationBarTitleDisplayMode(.inline)
        .hideBackButtonOptionally()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { navBarLeadingView }
            ToolbarItem(placement: .navigationBarTrailing) { navBarTrailingView }
        }
        .toast(isPresenting: $showAlert, alert: {
            detailsViewModel.isInWatchList == false ?
            AlertToast(displayMode: .alert, type: .error(.red), title: "Removed from Watchlist")  :
            AlertToast(displayMode: .alert, type: .complete(.green), title: "Added to Watchlist")
        })
        .sheet(isPresented: $videoPresented) {
            WebView(videoURL: detailsViewModel.videos?.getVideoURL())
                .ignoresSafeArea()
        }
        .sheet(isPresented: $isWatchNowPresented) {
            WebView(videoURL: detailsViewModel.watchNowURL)
                .ignoresSafeArea()
        }
        .safeAreaInset(edge: .bottom) {
            if detailsViewModel.viewModelFinishedFetching,
               detailsViewModel.watchNowURL != nil {
                stickyWatchNowCTA
            }
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

// MARK: - Content

extension ContentDetailsView {

    fileprivate func constructContent() -> some View {

        let result = detailsViewModel.result
        let screenType = detailsViewModel.screenType

        return VStack(spacing: 18) {

            MenuFeaturedView(results: [result],
                             overlayContent: { _ in
                                 HeroOverlayView(
                                    title: result.getResultTitle(),
                                    rating: detailsViewModel.details?.vote_average,
                                    year: yearString,
                                    runtimeOrSeasons: runtimeOrSeasonsString,
                                    genres: detailsViewModel.genresSafe
                                 )
                             },
                             screenType: screenType,
                             isTappable: false)

            primaryActionRow
            watchProvidersSection()
            detailsSection()
            seasonsSection()
            castSection()
            reviewsSection()
            moreLikeThisSection()
            additionalInfoSection()
        }
        .padding(.bottom, 24)
    }

    // MARK: - Hero meta helpers

    private var yearString: String? {
        let year = detailsViewModel.details?.getReleaseDate(addSeparator: false) ?? ""
        return year.isEmpty ? nil : year
    }

    /// Movies → "2h 15m". TV → "3 Seasons". Both fall back to nil silently.
    private var runtimeOrSeasonsString: String? {
        switch detailsViewModel.screenType {
        case .movie:
            return detailsViewModel.details?.getRuntime()
        case .tv:
            guard let seasons = detailsViewModel.details?.number_of_seasons, seasons > 0 else { return nil }
            return "\(seasons) Season\(seasons == 1 ? "" : "s")"
        case .person:
            return nil
        }
    }

    // MARK: - Primary action row

    @ViewBuilder
    private var primaryActionRow: some View {
        PrimaryActionRow(
            isInWatchList: detailsViewModel.isInWatchList,
            hasTrailer: detailsViewModel.videos?.getVideoURL() != nil,
            onWatchlistTap: toggleWatchlist,
            onTrailerTap: { videoPresented = true }
        )
    }

    // MARK: - Sticky bottom CTA
    //
    // Shown only when the title has a JustWatch provider link for the user's
    // region. Takes the viewer straight to where they can actually watch the
    // content — the highest-intent action on this screen. When no provider
    // link is available, the sticky hides entirely (no clutter).

    @ViewBuilder
    private var stickyWatchNowCTA: some View {
        Button {
            isWatchNowPresented = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                Text("Watch Now")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.accentColor, in: Capsule())
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }

    // MARK: - Shared actions

    private func toggleWatchlist() {
        if detailsViewModel.isInWatchList {
            WatchlistManager.removeFromWatchList(result: detailsViewModel.result)
            detailsViewModel.isInWatchList = false
        } else {
            WatchlistManager.addToWatchList(result: detailsViewModel.result)
            detailsViewModel.isInWatchList = true
        }
        showAlert = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
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

            SectionHeaderView(
                title: "Seasons",
                subtitle: "\(numberOfSeasons) Seasons | \(numberOfEpisodes) Episodes",
                icon: "rectangle.stack.fill",
                tint: .purple
            ) {
                Button {
                    isSeasonsSheetPresented.toggle()
                } label: {
                    Text("See all")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.purple)
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

            SectionHeaderView(
                title: "Available on",
                icon: "play.rectangle.fill",
                tint: .green
            )

            WatchProviderView(
                flatrates: provider.flatrate ?? [],
                rent: provider.rent ?? []
            )
        }
    }

    @ViewBuilder
    private func castSection() -> some View {
        if detailsViewModel.hasCast {
            SectionHeaderView(
                title: "Cast",
                icon: "person.2.fill",
                tint: .accentColor
            )
            CastView(cast: detailsViewModel.castSafe)
        }
    }

    @ViewBuilder
    private func reviewsSection() -> some View {
        if detailsViewModel.hasReviews {
            SectionHeaderView(
                title: "User Reviews",
                icon: "quote.bubble.fill",
                tint: .orange
            )
            ReviewsView(reviews: detailsViewModel.reviewsSafe)
        }
    }

    @ViewBuilder
    private func moreLikeThisSection() -> some View {
        MoreLikeThisSection(
            similars: detailsViewModel.similarsSafe,
            collection: detailsViewModel.collectionSafe,
            collectionName: detailsViewModel.details?.belongs_to_collection?.name,
            screenType: detailsViewModel.screenType,
            namespace: namespace
        )
    }

    @ViewBuilder
    private func additionalInfoSection() -> some View {
        if let details = detailsViewModel.details {
            AdditionalInfoView(details: details)
        }
    }
}
