//
//  OnboardingViewModel.swift
//  Watchnow
//
//  The three steps, and what happens at the end of them.
//
//  The whole shape of this file follows from one number in App Store
//  Connect: almost nobody who installs comes back the following month. A
//  first session that ends on an empty watchlist looks like every other
//  movie catalogue, so this ends on a full one — services chosen, taste
//  seeded, three titles saved, and a reason to be told when they land.
//
//  Every step is skippable and skipping is not a failure: onboarding is
//  marked complete either way, because "no thanks" is an answer and asking
//  again next launch would be the app refusing to hear it.
//

import Foundation

@MainActor
final class OnboardingViewModel: ObservableObject {

    enum Step: Int, CaseIterable {
        case services, loved, save, finish

        /// Only the three questions count towards the progress dots — the
        /// finish screen is the reward, not a fourth thing to get through.
        static var questionCount: Int { 3 }
    }

    // MARK: - Tunables

    static let requiredLoved = 5
    static let requiredSaves = 3
    /// Enough to scroll through without it becoming a chore.
    static let lovedCandidateCount = 30

    // MARK: - State

    @Published private(set) var step: Step = .services
    @Published private(set) var isLoading = false

    @Published private(set) var providers: [WatchProvider] = []
    @Published var selectedProviderIDs: Set<Int> = []

    @Published private(set) var lovedCandidates: [Result] = []
    /// Ordered, because the first pick is the one the finish screen asks
    /// Movie Coach about.
    @Published private(set) var lovedPickIDs: [Int] = []

    @Published private(set) var saveCandidates: [Result] = []
    @Published private(set) var savePickIDs: [Int] = []

    /// Built at the finish line, when there is something to say. Nil on a
    /// device without Foundation Models, or when the fetch didn't land.
    @Published private(set) var coachContext: MovieCoachContext?

    private let service: ServiceInvocation
    private var region: String { Locale.current.region?.identifier ?? "US" }

    init(service: ServiceInvocation = ServiceInvocation()) {
        self.service = service
    }

    // MARK: - Derived

    var canContinue: Bool {
        switch step {
        case .services: return !selectedProviderIDs.isEmpty
        case .loved:    return lovedPickIDs.count >= Self.requiredLoved
        case .save:     return savePickIDs.count >= Self.requiredSaves
        case .finish:   return true
        }
    }

    var progressText: String? {
        switch step {
        case .loved: return "\(min(lovedPickIDs.count, Self.requiredLoved)) of \(Self.requiredLoved)"
        case .save:  return "\(min(savePickIDs.count, Self.requiredSaves)) of \(Self.requiredSaves)"
        default:     return nil
        }
    }

    /// The titles saved in step 3, in the order they were picked — the
    /// posters the finish screen shows.
    var savedResults: [Result] {
        savePickIDs.compactMap { id in saveCandidates.first { $0.id == id } }
    }

    private var lovedResults: [Result] {
        lovedPickIDs.compactMap { id in lovedCandidates.first { $0.id == id } }
    }

    // MARK: - Selection

    func toggleProvider(_ id: Int) {
        if selectedProviderIDs.contains(id) { selectedProviderIDs.remove(id) }
        else { selectedProviderIDs.insert(id) }
    }

    func toggleLoved(_ id: Int) {
        if let index = lovedPickIDs.firstIndex(of: id) { lovedPickIDs.remove(at: index) }
        else { lovedPickIDs.append(id) }
    }

    func toggleSave(_ id: Int) {
        if let index = savePickIDs.firstIndex(of: id) { savePickIDs.remove(at: index) }
        else { savePickIDs.append(id) }
    }

    func isLovedPicked(_ id: Int?) -> Bool { id.map { lovedPickIDs.contains($0) } ?? false }
    func isSavePicked(_ id: Int?) -> Bool { id.map { savePickIDs.contains($0) } ?? false }

    // MARK: - Flow

    func start() async {
        await loadProviders()
    }

    /// Move on, whether they answered or skipped. `skipping` only changes
    /// whether the current step's picks are kept.
    func advance(skipping: Bool = false) async {
        if skipping { clearPicks(for: step) }

        switch step {
        case .services:
            commitServices()
            step = .loved
            await loadLovedCandidates()

        case .loved:
            commitLoved()
            step = .save
            await loadSaveCandidates()

        case .save:
            commitSaves()
            // Completion is marked on arrival, not on leaving: the finish
            // screen offers Coach and the notification prompt, and neither
            // is allowed to be a condition of having been onboarded.
            OnboardingState.markCompleted()
            step = .finish
            await loadCoachContext()

        case .finish:
            break
        }
    }

    // MARK: - Loading

    private func loadProviders() async {
        isLoading = providers.isEmpty
        providers = await StreamingProviderCatalog.load(region: region, using: service)
        isLoading = false
    }

    /// Well-known titles across both media types. Trending is the honest
    /// source for "have you seen any of these": it is what people are
    /// actually watching right now, in their region's flavour, without the
    /// app having to curate a list that ages.
    private func loadLovedCandidates() async {
        guard lovedCandidates.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        async let movies = try? service.fetchTrendingMovies(page: 1)
        async let series = try? service.fetchTrendingSeries(page: 1)
        let (movieResponse, seriesResponse) = await (movies, series)

        lovedCandidates = Self.interleaved(
            movies: Self.pickable(movieResponse?.results, mediaType: "movie"),
            series: Self.pickable(seriesResponse?.results, mediaType: "tv"),
            limit: Self.lovedCandidateCount)
    }

    /// Personalised by step 2 where possible. TMDB already knows what pairs
    /// with a title, so the union of its recommendations for the loved picks
    /// is a better opening watchlist than "here is what's popular" — and it
    /// costs three requests.
    private func loadSaveCandidates() async {
        isLoading = true
        defer { isLoading = false }

        let seeds = Array(lovedResults.prefix(3))
        var recommended: [Result] = []

        for seed in seeds {
            guard let id = seed.id else { continue }
            let type = seed.inferredScreenType
            if let response = try? await service.fetchRecommendations(screenType: type, id: id) {
                recommended += Self.pickable(response.results, mediaType: type.rawValue)
            }
        }

        let alreadyPicked = Set(lovedPickIDs)
        let personalised = Self.deduped(recommended).filter { !alreadyPicked.contains($0.id ?? -1) }

        if personalised.count >= Self.requiredSaves * 2 {
            saveCandidates = Array(personalised.prefix(Self.lovedCandidateCount))
            return
        }

        // Nothing loved, or TMDB had little to say — fall back to trending,
        // which is never empty and never personal.
        async let movies = try? service.fetchTrendingMovies(page: 1)
        async let series = try? service.fetchTrendingSeries(page: 1)
        let (movieResponse, seriesResponse) = await (movies, series)
        let fallback = Self.interleaved(
            movies: Self.pickable(movieResponse?.results, mediaType: "movie"),
            series: Self.pickable(seriesResponse?.results, mediaType: "tv"),
            limit: Self.lovedCandidateCount)

        saveCandidates = Self.deduped(personalised + fallback)
            .filter { !alreadyPicked.contains($0.id ?? -1) }
    }

    /// A real Coach verdict on the first title they saved, so the feature is
    /// met rather than described. Silent on any device where Coach isn't
    /// ready — no banner, no placeholder, nothing.
    private func loadCoachContext() async {
        guard MovieCoachService.isReady, let first = savedResults.first, let id = first.id else { return }
        let type = first.inferredScreenType

        // The same four fetches the details screen makes, in parallel. A
        // thinner context would have been cheaper, but this is the first
        // Coach verdict the user ever sees and it should not be the worst
        // one — `MovieCoachContext` reasons from cast and themes, and
        // handing it empties would make the opening read generic.
        async let details = try? service.fetchDetails(screenType: type, id: String(id))
        async let providerResponse = try? service.fetchWatchProviders(screenType: type, id: String(id))
        async let credits = try? service.fetchCredits(screenType: type, id: String(id))
        async let keywordResponse = try? service.fetchKeywords(screenType: type, id: String(id))

        let (detailsResponse, providers, creditsResponse, keywords) =
            await (details, providerResponse, credits, keywordResponse)
        guard let detailsResponse else { return }

        coachContext = MovieCoachContext.build(
            result: first,
            screenType: type,
            details: detailsResponse,
            cast: creditsResponse?.cast ?? [],
            similars: [],
            providerResults: providers?.results?[region],
            keywords: (keywords?.all ?? []).compactMap(\.name))
    }

    // MARK: - Committing

    private func clearPicks(for step: Step) {
        switch step {
        case .services: selectedProviderIDs = []
        case .loved:    lovedPickIDs = []
        case .save:     savePickIDs = []
        case .finish:   break
        }
    }

    private func commitServices() {
        guard !selectedProviderIDs.isEmpty else { return }
        StreamingPreferences.save(selectedProviderIDs)
    }

    private func commitLoved() {
        TasteSeeder.apply(lovedResults)
    }

    private func commitSaves() {
        for result in savedResults {
            WatchlistManager.addToWatchList(result: result)
        }
    }

    // MARK: - Shaping

    /// Drops anything without an id or a poster — a cover you can't see is
    /// not something you can recognise — and stamps the media type, which
    /// trending omits on some rows.
    private static func pickable(_ results: [Result]?, mediaType: String) -> [Result] {
        (results ?? []).compactMap { result in
            guard result.id != nil, result.poster_path != nil, !result.isPerson else { return nil }
            var typed = result
            typed.media_type = result.media_type ?? mediaType
            return typed
        }
    }

    private static func deduped(_ results: [Result]) -> [Result] {
        var seen = Set<Int>()
        return results.filter { seen.insert($0.id ?? -1).inserted }
    }

    /// Alternates films and shows so the grid reads as "both", not as a
    /// block of one followed by a block of the other.
    static func interleaved(movies: [Result], series: [Result], limit: Int) -> [Result] {
        var mixed: [Result] = []
        var movieIndex = 0, seriesIndex = 0
        while mixed.count < limit, movieIndex < movies.count || seriesIndex < series.count {
            if movieIndex < movies.count { mixed.append(movies[movieIndex]); movieIndex += 1 }
            if mixed.count < limit, seriesIndex < series.count {
                mixed.append(series[seriesIndex]); seriesIndex += 1
            }
        }
        return deduped(mixed)
    }
}
