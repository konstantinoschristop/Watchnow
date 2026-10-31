//
//  ProviderBrowseTests.swift
//  WatchnowTests
//
//  Unit coverage for a streaming service's "See all" screen: the Discover
//  URLs its filters build, the genre carried between Movies and Series, and
//  the view model's paging, stale-response handling and scoped search.
//
//  No network — a stub service answers from fixtures.
//

import XCTest
import SwiftUI
@testable import Watchnow

// MARK: - Query

final class ProviderCatalogQueryTests: XCTestCase {

    /// The feed's row goes through the same builder; with no filters set, its
    /// URL must be the one it always was.
    func testFeedRowURLIsUnchanged() {
        let url = API.Common.discoverByProvider(type: "movie", providerID: 8, region: "GR", page: 2)
        XCTAssertEqual(url, "\(API.baseURL)/discover/movie?api_key=\(API.key)&language=\(API.language)&watch_region=GR&with_watch_providers=8&with_watch_monetization_types=flatrate&sort_by=popularity.desc&page=2")
    }

    func testTopRatedSeriesInAGenre() {
        let query = ProviderCatalogQuery(providerID: 8, screenType: .tv, genreID: 35, sort: .topRated)
        let url = query.urlString(region: "GR", page: 1)

        XCTAssertTrue(url.contains("/discover/tv?"))
        XCTAssertTrue(url.contains("sort_by=vote_average.desc"))
        XCTAssertTrue(url.contains("&with_genres=35"))
        XCTAssertTrue(url.contains("&vote_count.gte=100"))
        XCTAssertFalse(url.contains(".lte="))
    }

    func testNewestCapsTheReleaseDateFieldForEachMediaType() throws {
        let day = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-31T12:00:00Z"))

        let movies = ProviderCatalogQuery(providerID: 8, screenType: .movie, sort: .newest)
            .urlString(region: "GR", page: 1, today: day, timeZone: .gmt)
        XCTAssertTrue(movies.contains("sort_by=primary_release_date.desc"))
        XCTAssertTrue(movies.contains("&primary_release_date.lte=2026-10-31"))

        let series = ProviderCatalogQuery(providerID: 8, screenType: .tv, sort: .newest)
            .urlString(region: "GR", page: 1, today: day, timeZone: .gmt)
        XCTAssertTrue(series.contains("sort_by=first_air_date.desc"))
        XCTAssertTrue(series.contains("&first_air_date.lte=2026-10-31"))
    }

    /// The cap is the user's today, not UTC's: half past eleven on 31 October
    /// in UTC is already 1 November in Athens, and still 30 October's evening
    /// in Los Angeles four hours earlier.
    func testNewestCapsAtTheUsersOwnToday() throws {
        let query = ProviderCatalogQuery(providerID: 8, screenType: .movie, sort: .newest)

        let lateInUTC = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-31T23:30:00Z"))
        let athens = try XCTUnwrap(TimeZone(identifier: "Europe/Athens"))
        XCTAssertTrue(query.urlString(region: "GR", page: 1, today: lateInUTC, timeZone: athens)
            .contains("&primary_release_date.lte=2026-11-01"))

        let earlyInUTC = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-31T03:00:00Z"))
        let losAngeles = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        XCTAssertTrue(query.urlString(region: "US", page: 1, today: earlyInUTC, timeZone: losAngeles)
            .contains("&primary_release_date.lte=2026-10-30"))
    }

    func testPopularHasNoVoteFloor() {
        let url = ProviderCatalogQuery(providerID: 8, screenType: .movie).urlString(region: "GR", page: 1)
        XCTAssertFalse(url.contains("vote_count.gte"))
    }

    /// Comedy is 35 for films and series alike; Action is 28 for a film and
    /// 10759 for a series, so it can't come along.
    func testSwitchingTypeKeepsASharedGenreAndDropsTheRest() {
        let comedy = ProviderCatalogQuery(providerID: 8, screenType: .movie, genreID: 35, sort: .newest)
        XCTAssertEqual(comedy.switching(to: .tv),
                       ProviderCatalogQuery(providerID: 8, screenType: .tv, genreID: 35, sort: .newest))

        let action = ProviderCatalogQuery(providerID: 8, screenType: .movie, genreID: 28)
        XCTAssertNil(action.switching(to: .tv).genreID)
    }
}

// MARK: - Brand colours

/// Every service's colours have to work on both appearances: the tint as
/// text on the page, the fill as a shape on a dark page, and the text on
/// the fill. Checked by resolving each colour the way UIKit draws it.
final class ProviderBrandTests: XCTestCase {

    private let light = UITraitCollection(userInterfaceStyle: .light)
    private let dark = UITraitCollection(userInterfaceStyle: .dark)

    func testEveryServiceHasAPalette() {
        XCTAssertFalse(ProviderBrand.knownProviderIDs.isEmpty)
        // The majors on the feed's chip bar, at least.
        for id in [8, 9, 337, 350, 1899, 531] {
            XCTAssertTrue(ProviderBrand.knownProviderIDs.contains(id), "no palette for \(id)")
        }
    }

    func testTintReadsAsTextOnBothAppearances() {
        for id in ProviderBrand.knownProviderIDs {
            let tint = UIColor(ProviderBrand.tint(for: id))
            XCTAssertGreaterThanOrEqual(contrast(tint.resolvedColor(with: light), .white), 4.5, "tint \(id) on light")
            XCTAssertGreaterThanOrEqual(contrast(tint.resolvedColor(with: dark), .black), 4.5, "tint \(id) on dark")
        }
    }

    func testFillStandsOutOnADarkPage() {
        for id in ProviderBrand.knownProviderIDs {
            let fill = UIColor(ProviderBrand.color(for: id)).resolvedColor(with: dark)
            XCTAssertGreaterThanOrEqual(contrast(fill, .black), 3, "fill \(id) on dark")
        }
    }

    func testTextOnTheFillReads() {
        for id in ProviderBrand.knownProviderIDs {
            for traits in [light, dark] {
                let fill = UIColor(ProviderBrand.color(for: id)).resolvedColor(with: traits)
                let text = UIColor(ProviderBrand.foreground(for: id)).resolvedColor(with: traits)
                XCTAssertGreaterThanOrEqual(contrast(fill, text), 2.8, "text on \(id), \(traits.userInterfaceStyle.rawValue)")
            }
        }
    }

    /// Light mode draws the logo colour exactly; only dark mode may lift it.
    func testLightModeFillIsTheLogoColour() {
        let netflix = UIColor(ProviderBrand.color(for: 8)).resolvedColor(with: light)
        var (r, g, b, a) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
        netflix.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(Int((r * 255).rounded()), 0xE5)
        XCTAssertEqual(Int((g * 255).rounded()), 0x09)
        XCTAssertEqual(Int((b * 255).rounded()), 0x13)
    }

    // MARK: WCAG

    private func contrast(_ a: UIColor, _ b: UIColor) -> Double {
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private func luminance(_ color: UIColor) -> Double {
        var (r, g, b, a) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        func linear(_ c: CGFloat) -> Double {
            let c = Double(c)
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }
}

// MARK: - Title logos

/// Which of a title's logos the heroes draw: the device language's, else
/// English, else one with no text — the best-rated of whichever that is.
final class TitleLogoPickTests: XCTestCase {

    private func logo(_ path: String, _ language: String?, votes: Double = 5, ratio: Double = 3) -> TitleLogoImage {
        TitleLogoImage(file_path: path, iso_639_1: language, aspect_ratio: ratio, vote_average: votes)
    }

    func testTheDeviceLanguageWins() {
        let picked = TitleLogoStore.pick([logo("/en.png", "en", votes: 9), logo("/el.png", "el", votes: 2)],
                                         languageCode: "el")
        XCTAssertTrue(picked?.url.absoluteString.hasSuffix("/el.png") == true)
    }

    func testEnglishThenTextlessAreTheFallbacks() {
        let english = TitleLogoStore.pick([logo("/none.png", nil), logo("/en.png", "en")], languageCode: "el")
        XCTAssertTrue(english?.url.absoluteString.hasSuffix("/en.png") == true)

        let textless = TitleLogoStore.pick([logo("/none.png", nil), logo("/de.png", "de")], languageCode: "el")
        XCTAssertTrue(textless?.url.absoluteString.hasSuffix("/none.png") == true)
    }

    func testTheBestRatedOfALanguageWinsAndCarriesItsShape() {
        let picked = TitleLogoStore.pick([logo("/a.png", "en", votes: 3, ratio: 2),
                                          logo("/b.png", "en", votes: 8, ratio: 6.5)],
                                         languageCode: "en")
        XCTAssertTrue(picked?.url.absoluteString.hasSuffix("/b.png") == true)
        XCTAssertEqual(picked?.aspectRatio, 6.5)
    }

    func testNoUsableLogoIsNone() {
        XCTAssertNil(TitleLogoStore.pick([], languageCode: "en"))
        XCTAssertNil(TitleLogoStore.pick([logo("/de.png", "de")], languageCode: "en"))
    }
}

// MARK: - Hero stills

/// Which still leads a hero: textless, sharp, and rated by more than one
/// person.
final class HeroStillRankingTests: XCTestCase {

    private func still(_ path: String, _ language: String? = nil,
                       votes: Double, count: Int, width: Int = 3840) -> TitleLogoImage {
        TitleLogoImage(file_path: path, iso_639_1: language, aspect_ratio: 16 / 9,
                       vote_average: votes, vote_count: count, width: width)
    }

    func testManyVotesOutrankOneStrayVote() {
        let ranked = TitleLogoStore.rankedTextless([still("/one-ten.jpg", votes: 10, count: 1),
                                                    still("/twenty-sevens.jpg", votes: 7, count: 20)])
        XCTAssertEqual(ranked, ["/twenty-sevens.jpg", "/one-ten.jpg"])
    }

    func testSharpStillsComeFirst() {
        let ranked = TitleLogoStore.rankedTextless([still("/small.jpg", votes: 9, count: 30, width: 1280),
                                                    still("/large.jpg", votes: 5, count: 3)])
        XCTAssertEqual(ranked.first, "/large.jpg")
    }

    // MARK: Trailers

    private func video(_ key: String, _ type: String, official: Bool) -> VideoModelResult {
        VideoModelResult(iso_639_1: "en", key: key, site: "YouTube", official: official, type: type)
    }

    func testAnOfficialTrailerWins() {
        let videos = VideoResponse(results: [video("fan", "Trailer", official: false),
                                             video("studio", "Trailer", official: true)])
        XCTAssertEqual(videos.trailerKey, "studio")
    }

    func testATrailerNobodyMarkedOfficialStillCounts() {
        // Most older series on TMDB: the trailer is there, uploaded by
        // someone other than the studio.
        let videos = VideoResponse(results: [video("credits", "Opening Credits", official: true),
                                             video("trailer", "Trailer", official: false)])
        XCTAssertEqual(videos.trailerKey, "trailer")
    }

    func testATeaserBeforeNothingButNeverAClip() {
        XCTAssertEqual(VideoResponse(results: [video("teaser", "Teaser", official: true)]).trailerKey, "teaser")
        XCTAssertNil(VideoResponse(results: [video("clip", "Clip", official: true),
                                             video("bts", "Behind the Scenes", official: true)]).trailerKey)
    }

    func testOnlyTextlessStillsAndTMDBOrderBreaksTies() {
        let ranked = TitleLogoStore.rankedTextless([still("/a.jpg", votes: 0, count: 0),
                                                    still("/titled.jpg", "en", votes: 9, count: 40),
                                                    still("/b.jpg", votes: 0, count: 0)])
        XCTAssertEqual(ranked, ["/a.jpg", "/b.jpg"])
    }
}

// MARK: - View model

@MainActor
final class ProviderBrowseViewModelTests: XCTestCase {

    private let netflix = WatchProvider(provider_id: 8, provider_name: "Netflix", logo_path: nil, display_priority: 0)
    private let disney = WatchProvider(provider_id: 337, provider_name: "Disney Plus", logo_path: nil, display_priority: 1)
    private let apple = WatchProvider(provider_id: 350, provider_name: "Apple TV", logo_path: nil, display_priority: 2)

    private func viewModel(_ service: StubCatalogService) -> ProviderBrowseViewModel {
        ProviderBrowseViewModel(providers: [netflix, disney], provider: netflix,
                                screenType: .movie, region: "GR", service: service)
    }

    func testPagesAppendWithoutDuplicatesOrPosterlessTitles() async {
        let service = StubCatalogService { _, page in
            switch page {
            case 1:  return page1([fixture(1), fixture(2), fixture(3, poster: false)], totalPages: 3)
            default: return page1([fixture(2), fixture(4)], totalPages: 3)
            }
        }
        let vm = viewModel(service)

        vm.loadIfNeeded()
        await settle { vm.phase == .loaded }
        XCTAssertEqual(vm.results.compactMap(\.id), [1, 2])
        XCTAssertEqual(vm.results.first?.media_type, "movie")

        vm.loadMore()
        await settle { vm.results.count == 3 }
        XCTAssertEqual(vm.results.compactMap(\.id), [1, 2, 4])
        XCTAssertTrue(vm.canLoadMore)
    }

    /// The unfiltered page answers late: the user has picked a genre, and
    /// the genre's page has landed, before it does. The grid must end up
    /// showing the genre. The order is pinned with a gate rather than raced
    /// with sleeps, which could let the late page land after the assertion
    /// and pass whether or not it was dropped.
    func testAResponseForAnEarlierFilterIsDropped() async throws {
        let gate = Gate()
        let service = StubCatalogService { query, _ in
            if query.genreID == nil {
                await gate.wait()
                return page1([fixture(1)])
            }
            return page1([fixture(9)])
        }
        let vm = viewModel(service)

        vm.loadIfNeeded()
        vm.select(genreID: 35)
        await settle { vm.phase == .loaded }
        XCTAssertEqual(vm.results.compactMap(\.id), [9])

        // Only now does the earlier filter's page come back.
        gate.open()
        await settle { gate.passed == 1 }
        // It's back; give the view model its turn on the main actor to act on it.
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(vm.results.compactMap(\.id), [9])
        XCTAssertEqual(vm.resultsQuery.genreID, 35)
    }

    /// A filter tap keeps the current titles up, flagged as refreshing,
    /// until the new first page replaces them in one go.
    func testAFilterChangeKeepsTheOldTitlesUntilTheNewOnesLand() async {
        let gate = Gate()
        let service = StubCatalogService { query, _ in
            if query.genreID == 35 {
                await gate.wait()
                return page1([fixture(9)])
            }
            return page1([fixture(1), fixture(2)])
        }
        let vm = viewModel(service)
        vm.loadIfNeeded()
        await settle { vm.phase == .loaded }

        vm.select(genreID: 35)
        XCTAssertTrue(vm.isRefreshing)
        XCTAssertEqual(vm.phase, .loaded)
        XCTAssertEqual(vm.results.compactMap(\.id), [1, 2])
        XCTAssertNil(vm.resultsQuery.genreID, "results still answer the old query")

        gate.open()
        await settle { !vm.isRefreshing }
        XCTAssertEqual(vm.results.compactMap(\.id), [9])
        XCTAssertEqual(vm.resultsQuery.genreID, 35)
    }

    /// The hero is the service's billboard: a genre on top doesn't change
    /// it; another service does.
    func testTheHeroFollowsTheServiceNotTheGenre() async {
        let service = StubCatalogService { query, _ in
            let base = query.providerID * 100 + (query.genreID ?? 0)
            return page1([fixture(base + 1, backdrop: true)])
        }
        let vm = viewModel(service)
        vm.loadIfNeeded()
        await settle { vm.phase == .loaded }
        XCTAssertEqual(vm.heroTitles.compactMap(\.id), [801])

        vm.select(genreID: 35)
        await settle { vm.resultsQuery.genreID == 35 }
        XCTAssertEqual(vm.heroTitles.compactMap(\.id), [801])

        vm.select(provider: disney)
        await settle { vm.resultsQuery.providerID == 337 }
        XCTAssertEqual(vm.heroTitles.compactMap(\.id), [33736])
    }

    /// A service with nothing to put up, or whose first page fails, takes the
    /// last service's titles down with it rather than leaving them cycling
    /// under its own name.
    func testAServiceWithNothingToShowTakesTheHeroDown() async {
        let service = StubCatalogService { query, _ in
            switch query.providerID {
            case 8:   return page1([fixture(801)])
            case 337: return page1([])
            default:  throw URLError(.notConnectedToInternet)
            }
        }
        let vm = ProviderBrowseViewModel(
            providers: [netflix, disney, apple], provider: netflix,
            screenType: .movie, region: "GR", service: service)
        vm.loadIfNeeded()
        await settle { vm.phase == .loaded }
        XCTAssertEqual(vm.heroTitles.compactMap(\.id), [801])

        vm.select(provider: disney)
        await settle { vm.phase == .empty }
        XCTAssertTrue(vm.heroTitles.isEmpty)

        vm.select(provider: netflix)
        await settle { vm.phase == .loaded }
        XCTAssertEqual(vm.heroTitles.compactMap(\.id), [801])

        vm.select(provider: apple)
        await settle { vm.phase == .failed }
        XCTAssertTrue(vm.heroTitles.isEmpty)
    }

    func testAFailedFirstPageFailsTheScreen() async {
        let vm = viewModel(StubCatalogService { _, _ in throw URLError(.notConnectedToInternet) })

        vm.loadIfNeeded()
        await settle { vm.phase != .loading }

        XCTAssertEqual(vm.phase, .failed)
    }

    /// The first page adds nothing (no posters), so the view model reads on
    /// — and that read fails. With nothing listed, that's the screen failing,
    /// not a skeleton left up for good or an empty grid.
    func testAReadOnThatFailsWithNothingListedFailsTheScreen() async {
        let vm = viewModel(StubCatalogService { _, page in
            guard page == 1 else { throw URLError(.timedOut) }
            return page1([fixture(1, poster: false)], totalPages: 3)
        })

        vm.loadIfNeeded()
        await settle { vm.phase != .loading }

        XCTAssertEqual(vm.phase, .failed)
        XCTAssertFalse(vm.canLoadMore)
    }

    /// The same under a filter change, where the previous titles were up:
    /// they go, and the screen fails rather than showing an empty grid.
    func testAReadOnThatFailsDuringARefreshFailsTheScreen() async {
        let vm = viewModel(StubCatalogService { query, page in
            guard query.genreID == 35 else { return page1([fixture(1), fixture(2)]) }
            guard page == 1 else { throw URLError(.timedOut) }
            return page1([fixture(9, poster: false)], totalPages: 3)
        })
        vm.loadIfNeeded()
        await settle { vm.phase == .loaded }

        vm.select(genreID: 35)
        await settle { vm.phase != .loaded }

        XCTAssertEqual(vm.phase, .failed)
        XCTAssertFalse(vm.isRefreshing)
        XCTAssertTrue(vm.results.isEmpty)
    }

    /// Switching service mid-search drops the last service's answer at once:
    /// its split into "On" and "Not on" belongs to the old service.
    func testSwitchingServiceMidSearchDropsTheOldServicesAnswer() async {
        let service = StubCatalogService(search: [fixture(1, mediaType: "movie")],
                                         streaming: [1: [8]]) { _, _ in page1([]) }
        let vm = viewModel(service)
        vm.updateSearch("anything")
        vm.scheduleSearch(debounce: false)
        await settle { vm.searchResults != nil }
        XCTAssertEqual(vm.searchResults?.onService.compactMap(\.id), [1])

        vm.select(provider: disney)
        XCTAssertNil(vm.searchResults)

        await settle { vm.searchResults != nil }
        XCTAssertEqual(vm.searchResults?.onService.count, 0)
        XCTAssertEqual(vm.searchResults?.elsewhere.first?.streamingOn?.provider_id, 8)
    }

    /// Matches split by whether the service carries them, each half in TMDB's
    /// relevance order however the availability lookups happen to finish —
    /// the first match's lookup is the slowest here.
    func testSearchSplitsMatchesByAvailabilityInRelevanceOrder() async {
        let service = StubCatalogService(
            search: [fixture(1, mediaType: "movie"), fixture(2, mediaType: "tv"),
                     fixture(3, mediaType: "person"), fixture(4, mediaType: "movie"),
                     fixture(5, mediaType: "tv")],
            streaming: [1: [8], 2: [337], 4: [], 5: [8, 337]],
            slowLookups: [1]
        ) { _, _ in page1([]) }
        let vm = viewModel(service)

        vm.updateSearch("anything")
        vm.scheduleSearch(debounce: false)
        await settle { vm.searchResults != nil }

        let results = vm.searchResults
        XCTAssertEqual(results?.onService.compactMap(\.id), [1, 5])
        XCTAssertEqual(results?.elsewhere.map(\.id), [2, 4])
        XCTAssertEqual(results?.elsewhere.first?.streamingOn?.provider_id, 337)
        XCTAssertNil(results?.elsewhere.last?.streamingOn)
    }

    func testClearingTheSearchLeavesSearchMode() async {
        let service = StubCatalogService(search: [fixture(1, mediaType: "movie")],
                                         streaming: [1: [8]]) { _, _ in page1([]) }
        let vm = viewModel(service)

        vm.updateSearch("anything")
        vm.scheduleSearch(debounce: false)
        await settle { vm.searchResults != nil }
        vm.clearSearch()

        XCTAssertFalse(vm.isSearching)
        XCTAssertNil(vm.searchResults)
    }

    // MARK: Helpers

    /// Polls until `condition` holds or two seconds pass, whichever is first.
    private func settle(_ condition: () -> Bool) async {
        let deadline = ContinuousClock.now + .seconds(2)
        while !condition(), ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }
}

// MARK: - Fixtures

private func fixture(_ id: Int, poster: Bool = true, mediaType: String? = nil, backdrop: Bool = false) -> Result {
    Result(backdrop_path: backdrop ? "/backdrop\(id).jpg" : nil, first_air_date: nil, genre_ids: nil, id: id,
           original_title: nil, name: nil, origin_country: nil,
           original_language: "en", original_name: nil, overview: nil,
           popularity: nil, poster_path: poster ? "/poster\(id).jpg" : nil, release_date: nil,
           title: "Title \(id)", video: nil, vote_average: nil, vote_count: nil,
           media_type: mediaType, profile_path: nil, castID: nil, runtime: nil, known_for: nil)
}

private func page1(_ results: [Result], totalPages: Int = 1) -> GenericResultResponse {
    GenericResultResponse(results: results, total_pages: totalPages, total_results: results.count)
}

/// Holds a stub's answer until the test lets it through, so the order two
/// responses land in is pinned by the test instead of raced on the clock.
@MainActor
private final class Gate {
    private var isOpen = false
    private var waiting: [CheckedContinuation<Void, Never>] = []
    /// How many answers it has let through.
    private(set) var passed = 0

    func wait() async {
        if !isOpen {
            await withCheckedContinuation { waiting.append($0) }
        }
        passed += 1
    }

    func open() {
        isOpen = true
        waiting.forEach { $0.resume() }
        waiting = []
    }
}

/// Answers the catalogue from a closure and search from fixtures. Everything
/// it holds is set once at init, which is what makes the unchecked
/// `Sendable` honest.
private final class StubCatalogService: ProviderCatalogServiceProtocol, @unchecked Sendable {

    let catalogue: @Sendable (ProviderCatalogQuery, Int) async throws -> GenericResultResponse
    let search: [Result]
    /// Title id → the ids of the services streaming it in "GR".
    let streaming: [Int: [Int]]
    /// Title ids whose availability lookup takes a while.
    let slowLookups: Set<Int>

    init(search: [Result] = [],
         streaming: [Int: [Int]] = [:],
         slowLookups: Set<Int> = [],
         catalogue: @escaping @Sendable (ProviderCatalogQuery, Int) async throws -> GenericResultResponse) {
        self.catalogue = catalogue
        self.search = search
        self.streaming = streaming
        self.slowLookups = slowLookups
    }

    func fetchProviderCatalog(_ query: ProviderCatalogQuery,
                              region: String,
                              page: Int) async throws -> GenericResultResponse {
        try await catalogue(query, page)
    }

    func fetchSearchResults(search: String) async throws -> SearchResponse {
        SearchResponse(results: self.search)
    }

    func fetchWatchProviders(screenType: ScreenTypes, id: String) async throws -> WatchProvidersResponse {
        let id = Int(id) ?? 0
        if slowLookups.contains(id) {
            try await Task.sleep(for: .milliseconds(80))
        }
        let flatrate = (streaming[id] ?? []).map {
            Flatrate(logoPath: nil, providerID: $0, providerName: "Service \($0)", displayPriority: nil)
        }
        return WatchProvidersResponse(id: id,
                                      results: ["GR": ProviderResults(link: nil, flatrate: flatrate, rent: nil, buy: nil)])
    }
}
