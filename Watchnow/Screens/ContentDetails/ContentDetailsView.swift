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
    @State private var isReminderOn = false
    @State private var showReminderAlert = false
    @State private var showNotificationSettingsAlert = false
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
                    // Subtle inline banner — sits below all content sections,
                    // takes up no space until a creative loads.
                    InlineBannerSection()
                        .padding(.top, 4)
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
        .alert("Notifications are off",
               isPresented: $showNotificationSettingsAlert) {
            Button("Open Settings") { ReminderManager.openNotificationSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enable notifications for Watchnow in Settings to set release reminders.")
        }
        .toast(isPresenting: $showReminderAlert, alert: {
            isReminderOn ?
            AlertToast(displayMode: .alert, type: .complete(.green), title: "Reminder Set") :
            AlertToast(displayMode: .alert, type: .error(.red), title: "Reminder Removed")
        })
        .sheet(isPresented: $videoPresented) {
            WebViewSheet(url: detailsViewModel.videos?.getVideoURL())
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
            // Single static image — no carousel interaction needed.
            // Disabling hit-testing lets the parent ScrollView receive
            // vertical pan gestures that start on the hero.
            .allowsHitTesting(false)

            primaryActionRow
                .padding(.top, -32)
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

    private func syncReminderState() {
        guard let identifier = detailsViewModel.reminderIdentifier else {
            isReminderOn = false
            return
        }
        isReminderOn = ReminderManager.isScheduled(identifier: identifier)
    }

    private func toggleReminder() {
        guard let identifier = detailsViewModel.reminderIdentifier,
              let releaseDate = detailsViewModel.futureReleaseDate else {
            return
        }

        if isReminderOn {
            ReminderManager.cancel(identifier: identifier)
            isReminderOn = false
            showReminderAlert = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }

        let title = detailsViewModel.result.getResultTitle()
        let body = detailsViewModel.screenType == .movie
            ? "\(title) is out today — time to watch."
            : "\(title) starts today — time to tune in."
        let deepLink = detailsViewModel.reminderDeepLink

        Task {
            let result = await ReminderManager.schedule(
                identifier: identifier,
                title: "Out now",
                body: body,
                on: releaseDate,
                deepLink: deepLink
            )
            switch result {
            case .scheduled:
                isReminderOn = true
                showReminderAlert = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .authorizationDenied:
                showNotificationSettingsAlert = true
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            case .failed:
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        }
    }

    // MARK: - Shared actions

    private func toggleWatchlist() {
        if detailsViewModel.isInWatchList {
            WatchlistManager.removeFromWatchList(result: detailsViewModel.result)
            detailsViewModel.isInWatchList = false
        } else {
            let added = WatchlistManager.addToWatchList(result: detailsViewModel.result)
            detailsViewModel.isInWatchList = true
            if added {
                ReviewRequestManager.recordWatchlistAdd()
                ReviewRequestManager.requestReviewIfAppropriate()
            }
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
            if detailsViewModel.futureReleaseDate != nil {
                Button(action: toggleReminder) {
                    getnavBarLabel(imageName: isReminderOn ? "bell.fill" : "bell")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isReminderOn ? "Cancel reminder" : "Remind me on release")
            }

            if let url = URL(string: detailsViewModel.createShareLink()) {
                ShareLink(item: url) {
                    getnavBarLabel(imageName: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 5)
        .task {
            await ReminderManager.reconcileWithSystem()
            syncReminderState()
        }
        .onChange(of: detailsViewModel.reminderIdentifier) { _, _ in
            syncReminderState()
        }
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
                tint: .accentColor
            ) {
                Button {
                    isSeasonsSheetPresented.toggle()
                } label: {
                    Text("See all")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
            }

            SeasonsView(seasons: seasons,
                        navBarTitle: name,
                        seriesID: seriesID,
                        selectedSeason: $detailsViewModel.selectedSeason,
                        isSheetPresented: $isSeasonsSheetPresented)
                .sheet(isPresented: $isSeasonsSheetPresented) {
                    SeasonsDetailsTabView(
                        seasons: seasons,
                        selectedSeason: $detailsViewModel.selectedSeason,
                        seriesID: seriesID,
                        seriesName: name
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
                tint: .accentColor
            )

            WatchProviderView(
                flatrates: provider.flatrate ?? [],
                rent: provider.rent ?? [],
                buy: provider.buy ?? [],
                justWatchURL: detailsViewModel.watchNowURL
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
            CastView(cast: detailsViewModel.castSafe,
                     currentTitleID: detailsViewModel.result.id)
        }
    }

    @ViewBuilder
    private func reviewsSection() -> some View {
        if detailsViewModel.hasReviews {
            SectionHeaderView(
                title: "User Reviews",
                icon: "quote.bubble.fill",
                tint: .accentColor
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
