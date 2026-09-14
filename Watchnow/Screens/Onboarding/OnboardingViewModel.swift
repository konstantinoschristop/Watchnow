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
        case welcome, services, loved, save, finish

        /// Only the three questions count towards the progress dots. The
        /// welcome screen is the door and the finish screen is the reward;
        /// neither is a thing to get through.
        static var questionCount: Int { 3 }

        /// Position among the questions, or nil for the screens that book-end
        /// them.
        var questionIndex: Int? {
            switch self {
            case .services: return 0
            case .loved:    return 1
            case .save:     return 2
            default:        return nil
            }
        }
    }

    // MARK: - Tunables

    static let requiredLoved = 5
    static let requiredSaves = 3
    /// Enough to scroll through without it becoming a chore.
    static let lovedCandidateCount = 30

    // MARK: - State

    @Published private(set) var step: Step = .welcome
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

    /// The one in-flight trending fetch, if any. See `loadLovedCandidates`.
    private var lovedCandidatesTask: Task<Void, Never>?


    init(service: ServiceInvocation = ServiceInvocation()) {
        self.service = service
    }

    // MARK: - Derived

    var canContinue: Bool {
        switch step {
        case .welcome:  return true
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

    /// Artwork for the drifting wall behind the whole flow.
    ///
    /// Deliberately the *same* trending fetch the second step picks from,
    /// rather than a separate request: the wall is then free, and by the
    /// time the user reaches the loved grid every cover in it has already
    /// been through Kingfisher's cache, so the step that used to open on
    /// thirty grey rectangles now opens on thirty posters.
    var wallPosters: [URL] {
        lovedCandidates.compactMap { $0.poster_path == nil ? nil : $0.getPosterURL(width: .poster) }
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
        // Both at once. The providers are what the first question needs;
        // the trending feed is what the backdrop needs, and the backdrop is
        // on screen from the first frame — waiting for the providers before
        // asking for it would leave the welcome screen flat for as long as
        // two round trips take.
        async let providers: Void = loadProviders()
        async let candidates: Void = loadLovedCandidates(showingSpinner: false)
        _ = await (providers, candidates)
    }

    /// Move on, whether they answered or skipped. `skipping` only changes
    /// whether the current step's picks are kept.
    func advance(skipping: Bool = false) async {
        if skipping { clearPicks(for: step) }

        switch step {
        case .welcome:
            step = .services

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
            // Both after the step change, so the payoff screen is not
            // waiting on them. Arming the nudge queries the notification
            // settings and Coach makes four fetches; neither has anything
            // to do with whether the screen can be drawn.
            await armWatchNudge()
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
    /// `showingSpinner` is off when this runs at launch to fill the
    /// backdrop: the welcome screen is not waiting on it, and a progress
    /// spinner over a screen that is already complete reads as a stall.
    ///
    /// Callers share one fetch. `guard lovedCandidates.isEmpty` was enough
    /// when there was a single call site; there are now two — the launch
    /// backdrop and the second step — and on a slow connection the second
    /// arrives while the first is still in flight, sees an empty array, and
    /// starts an identical request whose spinner then sits on top of the
    /// grid the first one just populated. Awaiting the existing task
    /// instead means the second caller's spinner is shown for exactly as
    /// long as there is genuinely nothing to show.
    private func loadLovedCandidates(showingSpinner: Bool = true) async {
        guard lovedCandidates.isEmpty else { return }

        if showingSpinner { isLoading = true }
        defer { if showingSpinner { isLoading = false } }

        // Cleared when it finishes, so a fetch that came back with nothing
        // can be retried by the next caller rather than remembered as done.
        if lovedCandidatesTask == nil {
            lovedCandidatesTask = Task { [weak self] in
                await self?.fetchLovedCandidates()
                self?.lovedCandidatesTask = nil
            }
        }
        await lovedCandidatesTask?.value
    }

    private func fetchLovedCandidates() async {
        async let movies = try? service.fetchTrendingMovies(page: 1)
        async let series = try? service.fetchTrendingSeries(page: 1)
        let (movieResponse, seriesResponse) = await (movies, series)

        lovedCandidates = Self.interleaved(
            movies: Self.pickable(movieResponse?.results, mediaType: "movie"),
            series: Self.pickable(seriesResponse?.results, mediaType: "tv"),
            limit: Self.lovedCandidateCount)
    }

    /// What to offer as an opening watchlist.
    ///
    /// This used to be the union of TMDB's `/recommendations` for the loved
    /// picks, and it produced a bad screen. Recommendations are unfiltered
    /// and mostly *adjacent* rather than good: seed it with Moana and it
    /// offers Ruby Gillman, Nim's Island and The Pirates! — obscure, years
    /// old, and nothing anyone would choose to start a watchlist with.
    ///
    /// So the sources changed rather than the ranking being patched. Every
    /// pool here is something a person could plausibly watch *this week*,
    /// and the loved picks are spent on ordering them rather than on finding
    /// them:
    ///
    /// - Discover, per media type, scoped to the genres they just told us
    ///   they love and to the services they said they have. This is the
    ///   "relevant *and* watchable" pool and it leads the ranking.
    /// - What is in cinemas now, and what is airing this week.
    /// - The trending feed already fetched at launch for the backdrop, as a
    ///   free backstop that is never empty.
    ///
    /// Four requests, all at once, and the trending pool costs nothing.
    private func loadSaveCandidates() async {
        isLoading = true
        defer { isLoading = false }

        let weights = lovedGenreWeights
        // Three is enough to steer Discover without narrowing it to the
        // point where the provider filter leaves nothing.
        let genres = weights.sorted { $0.value > $1.value }.prefix(3).map(\.key)
        let providers = Array(selectedProviderIDs)

        // An empty `genres` or `providers` simply drops that filter from the
        // query, which degrades to "popular right now" — still a better
        // screen than recommendations were, so a user who skipped step two
        // needs no separate path.
        async let onServiceMovies = try? service.discover(
            screenType: .movie, genreIDs: genres, providerIDs: providers, region: region)
        async let onServiceSeries = try? service.discover(
            screenType: .tv, genreIDs: genres, providerIDs: providers, region: region)
        async let inCinemas = try? service.fetchNowPlayingMovies()
        async let airingNow = try? service.fetchOnTheAirSeries()

        let (serviceMovies, serviceSeries, cinemas, airing) =
            await (onServiceMovies, onServiceSeries, inCinemas, airingNow)

        // Tiers, not one flat pool. Ranking everything together let a
        // six-genre anime from 2016 outscore a film released last month,
        // because breadth of genre tags is not the same thing as relevance.
        // Sorting by source first makes the promise in the subtitle literally
        // true: what you can watch on your services comes first, what is on
        // right now comes next, and trending only fills the tail.
        let movies = Self.pooled(serviceMovies?.results, mediaType: "movie",
                                 source: .onYourServices, minimumVotes: 200)
                   + Self.pooled(cinemas?.results, mediaType: "movie",
                                 source: .onRightNow, minimumVotes: 50)
                   + Self.pooled(lovedCandidates.filter { $0.media_type == "movie" },
                                 mediaType: "movie", source: .trending, minimumVotes: 200)
        let series = Self.pooled(serviceSeries?.results, mediaType: "tv",
                                 source: .onYourServices, minimumVotes: 200)
                   + Self.pooled(airing?.results, mediaType: "tv",
                                 source: .onRightNow, minimumVotes: 200)
                   + Self.pooled(lovedCandidates.filter { $0.media_type == "tv" },
                                 mediaType: "tv", source: .trending, minimumVotes: 200)

        // Nothing they have already said yes to, here or on a previous
        // device — an opening watchlist that offers back what is already in
        // the watchlist is the app not paying attention.
        var excluded = Set(lovedPickIDs)
        excluded.formUnion(WatchlistManager.watchlist.compactMap(\.id))

        // Recorded before ranking throws the tags away. The pools are
        // already in source order, so a title in two of them keeps the more
        // specific claim.
        for candidate in movies + series {
            guard let id = candidate.result.id else { continue }
            if candidate.source.rawValue < (sourceByID[id]?.rawValue ?? Int.max) {
                sourceByID[id] = candidate.source
            }
        }

        saveCandidates = Self.interleaved(
            movies: Self.ranked(movies, excluding: excluded, by: weights),
            series: Self.ranked(series, excluding: excluded, by: weights),
            limit: Self.lovedCandidateCount)
    }

    /// Where each step-three candidate came from, kept so the finish screen
    /// can say something true.
    private var sourceByID: [Int: Source] = [:]

    /// What is actually going to happen to the titles they just saved.
    ///
    /// The finish screen used to say "We'll tell you when these land"
    /// unconditionally, and that is a promise the app frequently cannot
    /// keep. There are exactly two automatic alerts — see `AutoAlertPolicy`
    /// — and both fire on a *change*: a saved series' next episode airing,
    /// and a saved title *newly* appearing on a service the user has.
    /// Neither can ever fire for something that was already streaming when
    /// it was saved, and once step three started leading with "on your
    /// services right now" that became the common case rather than the rare
    /// one. A user whose three picks are all already streaming would have
    /// been promised notifications that are, by construction, impossible.
    ///
    /// So the line is derived rather than assumed.
    enum Payoff {
        /// They skipped, so there is nothing to promise anything about.
        case nothingSaved
        /// Every one is streaming on a service they told us they have.
        /// Nothing is going to land, because everything already has.
        case readyToWatch
        /// A film still in cinemas is among them. That one genuinely cannot
        /// be streamed yet, so the streaming alert really will fire for it.
        case landingLater
        /// A currently-airing series is among them, so episode alerts apply.
        case episodesAhead
        /// Some of each, or nothing we can claim with confidence.
        case mixed
    }

    /// Arranges the one nudge for a film that is already streaming.
    ///
    /// Three conditions, each closing off a case the app already covers. A
    /// cinema release will produce a real streaming alert when it lands. An
    /// airing series will produce episode alerts. And a *series* is excluded
    /// even when it is already streaming, because it can still air new
    /// episodes — and `AlertPlanner` suppresses an episode alert that shares
    /// a media id and a local day with a pending reminder, so a nudge about
    /// one could silently replace "a new episode airs today" with the far
    /// vaguer "it's on a service you have".
    ///
    /// The cost is a real gap: a *completed* series sitting on one of their
    /// services will never generate an alert of any kind, and now never gets
    /// nudged either. Closing it needs episode data this screen does not
    /// fetch, so it is left open knowingly rather than paid for with a
    /// notification that outranks a better one.
    private func armWatchNudge() async {
        guard !selectedProviderIDs.isEmpty,
              let ready = savedResults.first(where: {
                  sourceByID[$0.id ?? -1] == .onYourServices
                      && $0.inferredScreenType == .movie
              }),
              let id = ready.id
        else { return }

        await ReminderManager.armWatchNudge(mediaID: id,
                                            mediaType: ready.inferredScreenType.rawValue,
                                            title: ready.getResultTitle())
    }

    var payoff: Payoff {
        let saved = savedResults
        guard !saved.isEmpty else { return .nothingSaved }

        let tagged = saved.map { ($0, sourceByID[$0.id ?? -1] ?? .trending) }

        // "On a service you have" only means anything if they told us which
        // services those are. Without that the Discover query carried no
        // provider filter, and the tag means no more than "popular".
        if !selectedProviderIDs.isEmpty, tagged.allSatisfy({ $0.1 == .onYourServices }) {
            return .readyToWatch
        }

        let cinema = tagged.contains { $0.1 == .onRightNow && $0.0.media_type == "movie" }
        let airing = tagged.contains { $0.1 == .onRightNow && $0.0.media_type == "tv" }

        switch (cinema, airing) {
        case (true, false):  return .landingLater
        case (false, true):  return .episodesAhead
        default:             return .mixed
        }
    }

    /// Where a step-three candidate came from.
    ///
    /// Doubles as the ranking tier (lower first) and as the only honest
    /// signal the finish screen has about whether anything is ever going to
    /// *happen* to a saved title — see `payoff`.
    enum Source: Int {
        /// TMDB Discover scoped to the services they selected, filtered to
        /// `flatrate`. Streaming on one of their services right now.
        case onYourServices = 0
        /// In cinemas, or airing this week.
        case onRightNow = 1
        /// The trending feed. Says nothing about availability.
        case trending = 2
    }

    /// One source's results, tagged with where they came from.
    private struct Candidate {
        let result: Result
        let source: Source
    }

    /// Shapes one pool: drops what can't be shown, applies the pool's own
    /// quality floor, and stamps its source.
    ///
    /// The floor is per-pool because the pools disagree about what a low
    /// vote count means. On `/tv/on_the_air` it means a daily soap nobody
    /// rates — that pool is where "Kamen Rider" and "Above & Below" came
    /// from. On `/movie/now_playing` it can simply mean a film released last
    /// Friday, which is exactly what this step wants to offer.
    private static func pooled(_ results: [Result]?,
                               mediaType: String,
                               source: Source,
                               minimumVotes: Int) -> [Candidate] {
        pickable(results, mediaType: mediaType)
            .filter { ($0.vote_count ?? 0) >= minimumVotes }
            .map { Candidate(result: $0, source: source) }
    }

    /// How often each genre appeared across the loved picks.
    ///
    /// Counting rather than setting: someone who picked four thrillers and
    /// one comedy should get a thriller-led screen, not an even split.
    private var lovedGenreWeights: [Int: Int] {
        var weights: [Int: Int] = [:]
        for result in lovedResults {
            for genre in result.genre_ids ?? [] { weights[genre, default: 0] += 1 }
        }
        return weights
    }

    /// Orders a pool by how well it matches the loved genres, with reach as
    /// the tie-break.
    ///
    /// Popularity is log-compressed on purpose. TMDB's figure is a long tail
    /// — one runaway release can score a hundred times a solid one — and
    /// left raw it would bulldoze the genre signal, which is the entire
    /// point of having asked the question.
    private static func ranked(_ candidates: [Candidate],
                               excluding excluded: Set<Int>,
                               by weights: [Int: Int]) -> [Result] {
        var seen = excluded
        return candidates
            // Deduped here rather than before, so a title present in two
            // pools keeps its most specific source — the pools are already
            // in source order.
            .filter { seen.insert($0.result.id ?? -1).inserted }
            .map { (candidate: $0, score: score($0.result, weights: weights)) }
            .sorted { ($0.candidate.source.rawValue, -$0.score) < ($1.candidate.source.rawValue, -$1.score) }
            .map(\.candidate.result)
    }

    /// Genre affinity, with reach as the tie-break.
    ///
    /// Affinity is divided by the square root of how many genres the title
    /// carries, so a title tagged with six of them doesn't out-match a
    /// focused one simply by covering more ground. Popularity is
    /// log-compressed for the same reason in the other direction: TMDB's
    /// figure is a long tail, and left raw one runaway release would
    /// bulldoze the genre signal that asking the question was for.
    private static func score(_ result: Result, weights: [Int: Int]) -> Double {
        let genres = result.genre_ids ?? []
        let matched = genres.reduce(0) { $0 + (weights[$1] ?? 0) }
        let affinity = genres.isEmpty ? 0 : Double(matched) / Double(genres.count).squareRoot()
        let reach = log10(max(result.popularity ?? 0, 1) + 1)
        return affinity * 3 + reach
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
        case .welcome, .finish: break
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
