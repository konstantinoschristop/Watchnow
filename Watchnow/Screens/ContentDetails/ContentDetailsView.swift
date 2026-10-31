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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion


    @StateObject var detailsViewModel: ContentDetailsViewModel
    @Environment(\.dismiss) var dismiss
    @State var videoPresented = false
    @State private var showAlert = false
    @State var isSeasonsSheetPresented = false
    @State private var isReminderOn = false
    /// Working copy of this title's automatic-alert switch. Mirrors
    /// `AlertPreferences`, which isn't observable — same shape as
    /// `isReminderOn` above and `isLiked` below.
    @State private var alertsOn = true
    @State private var showReminderAlert = false
    @State private var showAlertsToast = false
    @State private var showNotificationSettingsAlert = false
    @State private var isLiked = false
    @State private var isWatched = false
    /// The hero artwork's colour, washed faintly into the page.
    @State private var artworkTint: Color?
    /// The shareable image, made once the details have loaded.
    @State private var shareImage: UIImage?
    /// A sheet from one of the sections is up — see `CoversDetailsPageKey`.
    @State private var sectionSheetUp = false
    /// The trailer is playing in the hero; the Trailer action closes it.
    @State private var heroTrailerPlaying = false
    /// The hero is (mostly) on screen, under the status bar and nav buttons.
    /// While it is, it shades them itself — see the bar modifiers on `body`.
    @State private var heroInView = true
    @Namespace private var namespace

    /// True while this screen has nothing of its own to draw yet.
    ///
    /// A tap from a list hands over the whole `Result`, so the redaction
    /// below has real text and artwork to grey out. A tap from a notification
    /// or the What's New briefing arrives as `Result.stub` — id and media
    /// type only — and redacting nothing renders a blank page, which for the
    /// length of the fetch is indistinguishable from a broken screen. That
    /// was the "empty page" behind a briefing tap.
    private var isAwaitingFirstContent: Bool {
        detailsViewModel.details == nil
            && detailsViewModel.result.poster_path == nil
            && detailsViewModel.result.backdrop_path == nil
            && (detailsViewModel.result.title ?? detailsViewModel.result.name) == nil
    }

    var body: some View {

        // Measured out here, where the safe area still applies: the page
        // below runs up under the status bar and nav buttons, and the
        // hero's copy has to start beneath them on every device. A reader
        // inside the `ignoresSafeArea` scope reports an inset of zero.
        GeometryReader { proxy in
            Group {
                if detailsViewModel.apiError && !detailsViewModel.viewModelFinishedFetching {
                    ContentUnavailableView("Couldn't load content",
                                           systemImage: "exclamationmark.triangle",
                                           description: Text("Check your connection and try again."))
                } else if isAwaitingFirstContent {
                    DetailsSkeleton()
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        self.constructContent(topInset: proxy.safeAreaInsets.top)
                        // Subtle inline banner — sits below all content sections,
                        // takes up no space until a creative loads.
                        InlineBannerSection()
                            .padding(.top, 4)
                    }
                    // As on the Movies and Series tabs: the hero runs up under
                    // the status bar and nav buttons and shades them itself, so
                    // while it's there the bars' soft edge effect would only
                    // frost a band across the top of the artwork, stretching
                    // with it when pulled. It comes back once the hero has
                    // scrolled away and the page is passing under the bars.
                    .modifier(TopScrollEdgeEffectHidden(hidden: heroInView))
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .background(Color(.background))
        .toolbarBackground(heroInView ? .hidden : .automatic, for: .navigationBar)
        // The nav buttons sit on the hero's dark scrim: light, until the
        // hero has gone and the page is behind them.
        .toolbarColorScheme(heroInView ? .dark : nil, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .hideBackButtonOptionally()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { navBarLeadingView }
            ToolbarItem(placement: .navigationBarTrailing) { navBarTrailingView }
        }
        .toast(isPresenting: $showAlert, alert: {
            detailsViewModel.isInWatchList == false ?
            AlertToast(displayMode: .alert, type: .error(.red), title: String(localized: "Removed from Watchlist"))  :
            AlertToast(displayMode: .alert, type: .complete(.green), title: String(localized: "Added to Watchlist"))
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
            AlertToast(displayMode: .alert, type: .complete(.green), title: String(localized: "Reminder Set")) :
            AlertToast(displayMode: .alert, type: .error(.red), title: String(localized: "Reminder Removed"))
        })
        .toast(isPresenting: $showAlertsToast, alert: {
            alertsOn ?
            AlertToast(displayMode: .alert, type: .complete(.green), title: String(localized: "Alerts On", comment: "Toast: alerts turned on for this title")) :
            AlertToast(displayMode: .alert, type: .error(.red), title: String(localized: "Alerts Muted", comment: "Toast: alerts muted for this title"))
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
            async let keywords: Void = detailsViewModel.getKeywords()
            _ = await (credits, videos, providers, similars, reviews, collection, keywords)

            // If this title is saved, reconcile the stored copy with what we
            // just fetched — fresher poster, rating, dates, and which service
            // it streams on.
            detailsViewModel.syncWatchlistEntry()

            // Everything Movie Coach reads is now in place — let it build its
            // context and generate exactly once.
            detailsViewModel.allSectionsLoaded = true
        }
        // Drawn once everything is in, and again when the artwork's colour
        // arrives, so the card wears it.
        .task(id: ShareCardKey(loaded: detailsViewModel.allSectionsLoaded, tinted: artworkTint != nil)) {
            await makeShareCard()
        }
    }
}

// MARK: - Content

extension ContentDetailsView {

    fileprivate func constructContent(topInset: CGFloat) -> some View {

        let result = detailsViewModel.result

        return VStack(spacing: 18) {

            DetailsHeroView(kind: kindLabel,
                            title: result.getResultTitle(),
                            rating: detailsViewModel.details?.vote_average,
                            year: yearString,
                            runtimeOrSeasons: runtimeOrSeasonsString,
                            genres: detailsViewModel.genresSafe,
                            backdropPath: result.backdrop_path ?? detailsViewModel.details?.backdrop_path,
                            posterPath: result.poster_path,
                            topInset: topInset,
                            episodeMinutes: detailsViewModel.screenType == .tv ? detailsViewModel.details?.typicalEpisodeMinutes : nil,
                            certification: detailsViewModel.certification,
                            ownedServices: detailsViewModel.ownedServiceNames,
                            pageColor: pageTopColor,
                            onArtwork: takeTint(from:),
                            trailerKey: detailsViewModel.videos?.trailerKey,
                            isCovered: videoPresented || isSeasonsSheetPresented || sectionSheetUp,
                            trailerPlaying: $heroTrailerPlaying,
                            onFullTrailer: { videoPresented = true })
                .onScrollVisibilityChange(threshold: 0.3) { heroInView = $0 }

            primaryActionRow
                .padding(.top, -DetailsHeroView.actionOverlap)
            movieCoachSection()
            // Everything below arrives with its own request — see
            // `sectionArrival` — rather than being drawn empty and filled in.
            watchProvidersSection()
            detailsSection()
            seasonsSection()
            castSection()
            reviewsSection()
            moreLikeThisSection()
            additionalInfoSection()
        }
        .padding(.bottom, 24)
        // The artwork's colour, strongest under the hero and gone a screen
        // further down — so each title's page has its own light without the
        // cards losing their contrast.
        .background(alignment: .top) {
            LinearGradient(stops: [.init(color: pageTopColor, location: 0),
                                   .init(color: pageTopColor, location: 0.3),
                                   .init(color: Color(.background), location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 1200)
        }
        // No page-wide animation as sections land: SwiftUI drives one
        // frame by frame on the main thread, for everything below the
        // newcomer, and it stuttered the arrivals it was meant to smooth.
        // The placeholders hold each section's room instead, so there's
        // little left to move — each section animates only itself
        // (`sectionArrival`).
        // A section's sheet over the page stops the hero's trailer preview.
        .onPreferenceChange(CoversDetailsPageKey.self) { sectionSheetUp = $0 }
    }

    /// Requests are still out — sections without data yet hold their
    /// place with a `SectionPlaceholder` until then.
    private var isStillLoading: Bool {
        !detailsViewModel.allSectionsLoaded && !detailsViewModel.apiError
    }

    // MARK: - Artwork tint

    /// The page colour at the top: the background with a little of the
    /// artwork mixed in. Plain background until the artwork has loaded.
    private var pageTopColor: Color {
        guard let artworkTint else { return Color(.background) }
        return Color(.background).mix(with: artworkTint, by: 0.16)
    }

    private func takeTint(from image: UIImage) {
        guard artworkTint == nil else { return }
        Task.detached(priority: .userInitiated) {
            // An area average on a CoreImage context — blocking, so off
            // the main actor.
            guard let tint = image.heroTint else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.8)) { artworkTint = Color(tint) }
            }
        }
    }

    // MARK: - Share card

    /// Draws the share card once the details are in, from the images the
    /// page already loaded (or the cache).
    private func makeShareCard() async {
        guard detailsViewModel.allSectionsLoaded, let details = detailsViewModel.details else { return }
        let result = detailsViewModel.result

        async let poster = loadImage(result.poster_path ?? details.poster_path, width: .backdrop)
        async let backdrop = loadImage(result.backdrop_path ?? details.backdrop_path, width: .backdrop)
        var logos: [UIImage] = []
        for provider in (detailsViewModel.watchProviderSafe?.flatrate ?? []).prefix(4) {
            if let logo = await loadImage(provider.logoPath, width: .poster) { logos.append(logo) }
        }

        let card = TitleShareCard(title: result.getResultTitle(),
                                  kind: kindLabel,
                                  year: yearString,
                                  rating: details.vote_average,
                                  certification: detailsViewModel.certification,
                                  genres: detailsViewModel.genresSafe.map(\.displayName),
                                  poster: await poster,
                                  backdrop: await backdrop,
                                  tint: artworkTint ?? Color(red: 0.12, green: 0.14, blue: 0.2),
                                  providerLogos: logos)
        shareImage = card.render()
    }

    private func loadImage(_ path: String?, width: API.ImageWidth) async -> UIImage? {
        guard let path, !path.isEmpty,
              let url = URL(string: API.Common.imageUrl(imageId: path, width: width)) else { return nil }
        return await RemoteImageLoader.image(for: url)
    }

    private struct ShareCardKey: Hashable {
        let loaded: Bool
        let tinted: Bool
    }

    // MARK: - Hero meta helpers

    private var kindLabel: String? {
        switch detailsViewModel.screenType {
        case .movie:  return String(localized: "Movie", comment: "Media type label")
        case .tv:     return String(localized: "details.kind.series", defaultValue: "Series",
                                    comment: "Label above a series' title on its details screen. One series, singular.")
        case .person: return nil
        }
    }

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
            return String(localized: "\(seasons) Seasons", comment: "Number of seasons in a series")
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
            isSeries: detailsViewModel.screenType == .tv,
            isLiked: isLiked,
            isWatched: isWatched,
            isTrailerPlaying: heroTrailerPlaying,
            onWatchlistTap: toggleWatchlist,
            // Plays the trailer in the hero — or, while it's there, closes
            // it. The hero opens the full trailer when it can't play it.
            onTrailerTap: { heroTrailerPlaying.toggle() },
            onLikeTap: toggleLike,
            onWatchedTap: toggleWatched
        )
        .onAppear { syncLikeState() }
        .onChange(of: detailsViewModel.result.id) { _, _ in syncLikeState() }
        // A like made on another device can land while this screen is open.
        .onReceive(NotificationCenter.default.publisher(for: CloudSync.didMergeRemoteChanges)) { note in
            let keys = note.userInfo?[CloudSync.changedKeysKey] as? [String] ?? []
            if keys.contains("tasteLikedIDs") || keys.contains("watchedAtDates") { syncLikeState() }
        }
    }

    private func syncLikeState() {
        isLiked = TasteProfile.isLiked(detailsViewModel.result.id)
        isWatched = WatchedStore.isWatched(detailsViewModel.result.id)
    }

    /// Record that this has been seen.
    ///
    /// Deliberately independent of the watchlist: marking something watched
    /// does not unsave it, because the entry is finally worth something at
    /// exactly the moment it would otherwise be thrown away.
    private func toggleWatched() {
        guard let id = detailsViewModel.result.id else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) {
            isWatched = WatchedStore.toggle(id)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if isWatched { ReviewRequestManager.requestReview(for: .markedWatched) }
    }

    /// Records an explicit taste signal for this title. Kept separate from
    /// the watchlist: saving is "I might watch this", liking is "this is my
    /// kind of thing" — Movie Coach weighs them very differently.
    private func toggleLike() {
        guard let id = detailsViewModel.result.id else { return }
        let genreIDs = detailsViewModel.likeGenreIDs
        let language = detailsViewModel.result.original_language

        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) {
            if isLiked {
                TasteProfile.unlike(id: id, genreIDs: genreIDs, language: language)
                isLiked = false
            } else {
                TasteProfile.like(id: id, genreIDs: genreIDs, language: language)
                isLiked = true
            }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func syncReminderState() {
        alertsOn = !detailsViewModel.isAlertMuted

        guard let identifier = detailsViewModel.reminderIdentifier else {
            isReminderOn = false
            return
        }
        isReminderOn = ReminderManager.isScheduled(identifier: identifier)
    }

    /// Mute or unmute this title's automatic alerts.
    ///
    /// Turning them *on* is the one moment where asking iOS outright is
    /// right: the user has just pointed at a bell and asked to be told
    /// about this title, so the system prompt needs no preamble. A denial
    /// routes to the same "Notifications are off" alert the manual
    /// reminders have always used.
    private func toggleAlerts() {
        guard let id = detailsViewModel.result.id else { return }

        let turningOn = !alertsOn
        AlertPreferences.setOptedOut(!turningOn, for: id)
        alertsOn = turningOn
        showAlertsToast = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        guard turningOn else { return }
        Task {
            let permission = NotificationPermission.shared
            await permission.refreshStatus()
            guard !permission.isAuthorized else { return }
            if permission.canStillAsk {
                await permission.requestFromSettings()
            } else {
                showNotificationSettingsAlert = true
            }
        }
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
            ? String(localized: "\(title) is out today — time to watch.", comment: "Release reminder notification body, movie")
            : String(localized: "\(title) starts today — time to tune in.", comment: "Release reminder notification body, series")
        let deepLink = detailsViewModel.reminderDeepLink

        Task {
            let result = await ReminderManager.schedule(
                identifier: identifier,
                title: String(localized: "Out now", comment: "Release reminder notification title"),
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
            // Saved from a details screen, so the fresh facts and the
            // streaming service are already in hand — bank them now rather
            // than waiting for the next visit. The entry may well have come
            // from a list row carrying months-old artwork.
            detailsViewModel.syncWatchlistEntry()
            if added {
                // Saving is what subscribes the user to alerts, so it is
                // also the first moment asking iOS for permission means
                // anything. A no-op after the first time — see
                // `NotificationPermission.offerAfterSave`.
                Task { await NotificationPermission.shared.offerAfterSave() }
                ReviewRequestManager.recordWatchlistAdd()
                ReviewRequestManager.requestReview(for: .savedTitle)
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
            bellButton

            // Every share carries the App Store link, so whoever receives it
            // is one tap from the app: the card image with the link in the
            // message once the card is drawn, the link alone until then.
            let title = detailsViewModel.result.getResultTitle()
            let message = Text(ShareMessage.text(title: title))
            if let shareImage {
                let image = Image(uiImage: shareImage)
                ShareLink(item: image,
                          subject: Text(title),
                          message: message,
                          preview: SharePreview(title, image: image)) {
                    getnavBarLabel(imageName: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
            } else {
                ShareLink(item: ShareMessage.appStoreURL,
                          subject: Text(title),
                          message: message) {
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
        // Saving or unsaving flips the bell between "remind me on release"
        // and "mute this title" — or removes it entirely.
        .onChange(of: detailsViewModel.isInWatchList) { _, _ in
            syncReminderState()
        }
    }

    /// One glyph, two jobs — see `ContentDetailsViewModel.BellMode`.
    @ViewBuilder
    private var bellButton: some View {
        switch detailsViewModel.bellMode {
        case .releaseReminder:
            Button(action: toggleReminder) {
                getnavBarLabel(imageName: isReminderOn ? "bell.fill" : "bell")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isReminderOn ? "Cancel reminder" : "Remind me on release")

        case .automaticAlerts:
            Button(action: toggleAlerts) {
                getnavBarLabel(imageName: alertsOn ? "bell.fill" : "bell.slash")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(alertsOn ? "Mute alerts for this title" : "Turn alerts on for this title")
            .accessibilityHint(detailsViewModel.alertHint)

        case nil:
            EmptyView()
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

    /// On-device read on whether this title suits the user. Renders nothing
    /// at all when Foundation Models isn't available, and never blocks the
    /// rest of the screen.
    @ViewBuilder
    private func movieCoachSection() -> some View {
        if detailsViewModel.screenType != .person {
            MovieCoachView(context: detailsViewModel.coachContext,
                           posterPaths: detailsViewModel.coachPosterPaths)
        }
    }

    @ViewBuilder
    private func detailsSection() -> some View {
        if let overview = detailsViewModel.details?.overview, !overview.isEmpty {
            DetailsView(details: detailsViewModel.details)
                .sectionArrival(step: 1)
        } else if detailsViewModel.details == nil, isStillLoading {
            SectionPlaceholder(kind: .text)
        }
    }

    /// Season and episode ratings, with the way into every season's
    /// episode list as the card's footer.
    ///
    /// This replaced a grid of season tiles. Once the ratings card listed
    /// every aired season and opened its episodes, the grid was a second
    /// map of the same seasons a scroll below the first; what it still did
    /// that the chart doesn't — unaired seasons, their premiere reminders —
    /// lives in the sheet the footer opens.
    @ViewBuilder
    private func seasonsSection() -> some View {
        if detailsViewModel.screenType == .tv,
           detailsViewModel.hasSeasons,
           let seriesID = detailsViewModel.details?.id {
            let seasons = detailsViewModel.seasonsSafe
            let numberOfSeasons = detailsViewModel.details?.number_of_seasons ?? 0
            let numberOfEpisodes = detailsViewModel.details?.number_of_episodes ?? 0

            SeriesRatingsView(
                seasons: seasons,
                seriesID: seriesID,
                seasonsSummary: String(localized: "\(numberOfSeasons) Seasons", comment: "Number of seasons in a series")
                    + " · " + String(localized: "\(numberOfEpisodes) Episodes", comment: "Number of episodes"),
                onOpenSeason: { season in
                    if let season { detailsViewModel.selectedSeason = season }
                    isSeasonsSheetPresented = true
                }
            )
            // A different series pushed onto this screen must not inherit
            // the last one's cached episodes or selection.
            .id(seriesID)
            .sectionArrival(step: 2)
            .sheet(isPresented: $isSeasonsSheetPresented) {
                SeasonsDetailsTabView(
                    seasons: seasons,
                    initialSeason: detailsViewModel.selectedSeason,
                    seriesID: seriesID,
                    seriesName: detailsViewModel.details?.name ?? ""
                )
                .presentationDetents([.large])
            }
        } else if detailsViewModel.screenType == .tv, detailsViewModel.details == nil, isStillLoading {
            SectionPlaceholder(kind: .card(height: 420))
        }
    }

    @ViewBuilder
    private func watchProvidersSection() -> some View {
        if detailsViewModel.hasWatchProviders,
           let provider = detailsViewModel.watchProviderSafe {
            ProviderStripView(
                flatrates: provider.flatrate ?? [],
                rent: provider.rent ?? [],
                buy: provider.buy ?? [],
                justWatchURL: detailsViewModel.watchNowURL
            )
            .sectionArrival(step: 0)
        } else if isStillLoading {
            SectionPlaceholder(kind: .strip)
        }
    }

    @ViewBuilder
    private func castSection() -> some View {
        if detailsViewModel.hasCast {
            CastView(cast: detailsViewModel.castSafe,
                     crew: crewCredits,
                     currentTitleID: detailsViewModel.result.id)
                .sectionArrival(step: 3)
        } else if isStillLoading {
            SectionPlaceholder(kind: .carousel(width: 116, height: 156))
        }
    }

    /// Who made it, for the head of the cast row: a film's director(s), a
    /// series' creator(s).
    private var crewCredits: [CrewCredit] {
        switch detailsViewModel.screenType {
        case .movie:
            var seen = Set<Int>()
            return (detailsViewModel.credits?.crew ?? [])
                .filter { $0.job == "Director" }
                .compactMap { person -> CrewCredit? in
                    guard let id = person.id, seen.insert(id).inserted else { return nil }
                    return CrewCredit(id: id,
                                      name: person.getName(),
                                      role: String(localized: "Director", comment: "Badge on the director's photo in the cast row"),
                                      symbol: "video.fill",
                                      profilePath: person.profile_path)
                }
                .prefix(2)
                .map { $0 }
        case .tv:
            return (detailsViewModel.details?.created_by ?? [])
                .compactMap { person -> CrewCredit? in
                    guard let id = person.id else { return nil }
                    return CrewCredit(id: id,
                                      name: person.name ?? "",
                                      role: String(localized: "Creator", comment: "Badge on a series creator's photo in the cast row"),
                                      symbol: "lightbulb.fill",
                                      profilePath: person.profile_path)
                }
                .prefix(2)
                .map { $0 }
        case .person:
            return []
        }
    }

    @ViewBuilder
    private func reviewsSection() -> some View {
        if detailsViewModel.hasReviews {
            ReviewsView(reviews: detailsViewModel.reviewsSafe)
                .sectionArrival(step: 4)
        } else if isStillLoading {
            SectionPlaceholder(kind: .carousel(width: 300, height: 196))
        }
    }

    @ViewBuilder
    private func moreLikeThisSection() -> some View {
        if detailsViewModel.hasSimilars || detailsViewModel.hasCollection {
            MoreLikeThisSection(
                similars: detailsViewModel.similarsSafe,
                collection: detailsViewModel.collectionSafe,
                collectionName: detailsViewModel.details?.belongs_to_collection?.name,
                screenType: detailsViewModel.screenType,
                namespace: namespace
            )
            .sectionArrival(step: 5)
        } else if isStillLoading {
            SectionPlaceholder(kind: .carousel(width: 128, height: 192))
        }
    }

    @ViewBuilder
    private func additionalInfoSection() -> some View {
        if let details = detailsViewModel.details {
            AdditionalInfoView(details: details,
                               tmdbURL: URL(string: detailsViewModel.createShareLink()))
                .sectionArrival(step: 6)
        } else if isStillLoading {
            SectionPlaceholder(kind: .card(height: 260))
        }
    }
}
