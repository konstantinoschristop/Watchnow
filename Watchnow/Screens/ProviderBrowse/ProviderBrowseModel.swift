//
//  ProviderBrowseModel.swift
//  Watchnow
//
//  What a streaming service's "See all" screen asks TMDB for: that
//  service's subscription catalogue in the user's region, as movies or as
//  series, optionally narrowed to one genre and ordered one of three ways.
//
//  The feed's "Browse by Streaming" row is the first page of the most
//  popular titles and nothing else. This is the rest of the shelf.
//

import SwiftUI

// MARK: - Sort

/// How a service's catalogue is ordered.
enum ProviderBrowseSort: String, CaseIterable, Identifiable, Sendable {
    case popular
    case topRated
    case newest

    var id: Self { self }

    var title: String {
        switch self {
        case .popular:  return String(localized: "Popular", comment: "Streaming service catalogue sort option")
        case .topRated: return String(localized: "Top Rated", comment: "Streaming service catalogue sort option")
        case .newest:   return String(localized: "Newest", comment: "Streaming service catalogue sort option: most recently released first")
        }
    }

    var symbol: String {
        switch self {
        case .popular:  return "flame"
        case .topRated: return "star"
        case .newest:   return "calendar"
        }
    }
}

// MARK: - Query

/// Every filter on the screen, as one value. The view model fetches a page
/// *for* a query and drops the response if the query on screen has changed
/// since — two quick taps on different genres must not end with the first
/// genre's titles under the second genre's chip.
struct ProviderCatalogQuery: Hashable, Sendable {
    var providerID: Int
    var screenType: ScreenTypes
    /// nil = every genre.
    var genreID: Int?
    var sort: ProviderBrowseSort = .popular

    /// TMDB's `sort_by`. The release-date field is named per media type.
    var sortBy: String {
        switch sort {
        case .popular:  return "popularity.desc"
        case .topRated: return "vote_average.desc"
        case .newest:   return screenType == .tv ? "first_air_date.desc" : "primary_release_date.desc"
        }
    }

    /// Ranked on the average alone, a title with a single 10/10 vote leads
    /// the list. The floor keeps Top Rated to titles enough people have
    /// scored — lower for series, which draw far fewer votes than films.
    var voteCountGTE: Int? {
        guard sort == .topRated else { return nil }
        return screenType == .tv ? 100 : 300
    }

    /// The Discover URL for one page. `today` caps the release date when
    /// sorting by newest — the user's today, in their time zone: ISO 8601
    /// alone formats in UTC, which put the cap a day out around midnight,
    /// dropping today's releases east of Greenwich and letting tomorrow's in
    /// west of it. Both are parameters so a test can pin them.
    func urlString(region: String, page: Int, today: Date = .now, timeZone: TimeZone = .current) -> String {
        API.Common.discoverByProvider(type: screenType.rawValue,
                                      providerID: providerID,
                                      region: region,
                                      genreID: genreID,
                                      sortBy: sortBy,
                                      voteCountGTE: voteCountGTE,
                                      releasedOnOrBefore: sort == .newest
                                          ? today.formatted(Date.ISO8601FormatStyle(timeZone: timeZone).year().month().day())
                                          : nil,
                                      page: page)
    }

    /// The same query for the other media type. TMDB numbers some genres
    /// differently for series (Action is 28 for a film, 10759 for a show),
    /// so a genre only carries across when the new type has it too —
    /// Comedy and Drama do, Action resets to every genre.
    func switching(to screenType: ScreenTypes) -> ProviderCatalogQuery {
        var next = self
        next.screenType = screenType
        if let genreID, !Self.genreIDs(for: screenType).contains(genreID) {
            next.genreID = nil
        }
        return next
    }

    /// Genre chips offered for each media type, in rough order of how much
    /// of a typical catalogue they cover. TMDB's ids — the names come from
    /// `GenreNames`, in the device language.
    static func genreIDs(for screenType: ScreenTypes) -> [Int] {
        switch screenType {
        case .tv:
            // Drama, Comedy, Crime, Action & Adventure, Sci-Fi & Fantasy,
            // Mystery, Animation, Documentary, Family, Reality, Kids,
            // War & Politics, Western, Soap.
            return [18, 35, 80, 10759, 10765, 9648, 16, 99, 10751, 10764, 10762, 10768, 37, 10766]
        default:
            // Action, Comedy, Drama, Thriller, Horror, Sci-Fi, Romance,
            // Animation, Family, Crime, Documentary, Adventure, Fantasy,
            // Mystery, History, Music, War, Western.
            return [28, 35, 18, 53, 27, 878, 10749, 16, 10751, 80, 99, 12, 14, 9648, 36, 10402, 10752, 37]
        }
    }
}

// MARK: - Service

/// The endpoints the screen needs. A protocol so the view model's paging,
/// search and stale-response handling can be tested without a network.
protocol ProviderCatalogServiceProtocol: AnyObject, Sendable {
    func fetchProviderCatalog(_ query: ProviderCatalogQuery,
                              region: String,
                              page: Int) async throws -> GenericResultResponse

    /// TMDB's multi search. It can't be scoped to a service, so search on
    /// this screen checks each match's availability afterwards.
    func fetchSearchResults(search: String) async throws -> SearchResponse

    func fetchWatchProviders(screenType: ScreenTypes, id: String) async throws -> WatchProvidersResponse
}

// MARK: - Search

/// A search inside one service: the matches it carries, and the matches it
/// doesn't, with where each of those streams instead. The second half is
/// what makes the search worth having — "not on Netflix" is only half an
/// answer when the title is on Disney+.
struct ProviderSearchResults: Equatable {
    let query: String
    var onService: [Result]
    var elsewhere: [Elsewhere]

    struct Elsewhere: Hashable, Identifiable {
        let result: Result
        /// A subscription service carrying it in the region; nil when none does.
        let streamingOn: WatchProvider?
        var id: Int { result.id ?? 0 }
    }

    var isEmpty: Bool { onService.isEmpty && elsewhere.isEmpty }
}

// MARK: - Brand

/// Each service's colour, taken from the logo TMDB serves for it (sampled,
/// then checked by eye against the logo), and what it takes to use that
/// colour legibly on either appearance.
///
/// One colour can't do every job. MUBI's navy is a fine fill for a pill but
/// vanishes as text on a dark page; BritBox's pale blue does the same on a
/// light one. So each brand comes in four roles:
///
///  - `color`      the logo colour, for anything filled with it — lifted
///                 on a dark page until it stands out from it
///  - `foreground` text and symbols set on that fill
///  - `tint`       the brand as text or an icon on the page, pushed lighter
///                 or darker until it reads on that appearance's background
///  - `glow`       the light the screen is washed in
///
/// Max, Apple TV, Peacock and Zee5 have black-and-white logos. Their fill
/// follows the appearance (black in light mode, white in dark) and their
/// glow is a neutral grey, since a black or white haze reads as dirt, not
/// as a brand.
enum ProviderBrand {

    /// Services with a colour of their own; any other falls back to the
    /// app's accent.
    static var knownProviderIDs: Set<Int> { Set(swatches.keys) }

    static func color(for providerID: Int) -> Color {
        switch swatches[providerID] {
        case .logo(let rgb)?:
            return Color(uiColor: UIColor { traits in
                fill(rgb, isDark: traits.userInterfaceStyle == .dark).uiColor
            })
        case .monochrome?: return Color(uiColor: .label)
        case nil:          return .accentColor
        }
    }

    /// White unless the fill is too pale to carry it. The bar is 2.8:1, not
    /// WCAG's 4.5: Hulu's and Starz's logos set white on these very colours,
    /// and black text on a brand's own colour reads as someone else's brand.
    /// Judged against the fill as drawn, so per appearance.
    static func foreground(for providerID: Int) -> Color {
        switch swatches[providerID] {
        case .logo(let rgb)?:
            return Color(uiColor: UIColor { traits in
                let drawn = fill(rgb, isDark: traits.userInterfaceStyle == .dark)
                return drawn.contrast(with: .white) >= 2.8 ? .white : .black
            })
        case .monochrome?: return Color(uiColor: .systemBackground)
        case nil:          return .white
        }
    }

    /// The logo colour as a fill. On a dark page a dark brand is lifted to
    /// 3:1 against it — WCAG's bar for a shape to stand out — or MUBI's navy
    /// pill is a dark shape on a dark screen. Light mode draws it as is:
    /// even BritBox's pale blue reads as a coloured pill on white.
    private static func fill(_ rgb: RGB, isDark: Bool) -> RGB {
        isDark ? rgb.reaching(3, against: .black, movingToward: .white) : rgb
    }

    static func tint(for providerID: Int) -> Color {
        switch swatches[providerID] {
        case .logo(let rgb)?:
            return Color(uiColor: UIColor { traits in
                let isDark = traits.userInterfaceStyle == .dark
                return rgb.reaching(4.5, against: isDark ? .black : .white,
                                    movingToward: isDark ? .white : .black).uiColor
            })
        case .monochrome?: return Color(uiColor: .label)
        case nil:          return .accentColor
        }
    }

    static func glow(for providerID: Int) -> Color {
        switch swatches[providerID] {
        case .logo(let rgb)?: return Color(uiColor: rgb.uiColor)
        case .monochrome?:    return Color(uiColor: .systemGray)
        case nil:             return .accentColor
        }
    }

    private enum Swatch {
        case logo(RGB)
        case monochrome
    }

    /// Only services TMDB still lists. Showtime, Hotstar, JioCinema and
    /// Max's old id never come back from the region lists any more, so they
    /// never become chips and fall back to the accent colour if they do.
    private static let swatches: [Int: Swatch] = [
        8:    .logo(RGB(0xE50913)), // Netflix — the bright face of the N
        9:    .logo(RGB(0x0275FF)), // Prime Video
        119:  .logo(RGB(0x0275FF)),
        337:  .logo(RGB(0x066E7C)), // Disney+ — the teal light over its navy
        350:  .monochrome,          // Apple TV
        1899: .monochrome,          // HBO Max
        15:   .logo(RGB(0x1EAE5E)), // Hulu
        531:  .logo(RGB(0x2A68FA)), // Paramount+
        386:  .monochrome,          // Peacock
        387:  .monochrome,          // Peacock Premium Plus
        283:  .logo(RGB(0xFF5F02)), // Crunchyroll
        43:   .logo(RGB(0x48A5AC)), // Starz — the teal end of its wordmark
        520:  .logo(RGB(0x2556AA)), // Discovery+
        526:  .logo(RGB(0x1C9B9B)), // AMC+ — its teal wordmark
        11:   .logo(RGB(0x021589)), // MUBI
        151:  .logo(RGB(0xA6E2F5)), // BritBox — its pale blue tile
        39:   .logo(RGB(0x115459)), // NOW
        29:   .logo(RGB(0xFE0166)), // Sky Go — the pink heart of its gradient
        309:  .logo(RGB(0xC02346)), // Sun Nxt
        232:  .monochrome,          // Zee5
    ]
}

/// An sRGB colour with the WCAG arithmetic the palette needs.
private struct RGB: Sendable {
    let r, g, b: Double

    init(r: Double, g: Double, b: Double) {
        self.r = r; self.g = g; self.b = b
    }

    init(_ hex: UInt32) {
        self.init(r: Double((hex >> 16) & 0xFF) / 255,
                  g: Double((hex >> 8) & 0xFF) / 255,
                  b: Double(hex & 0xFF) / 255)
    }

    static let white = RGB(r: 1, g: 1, b: 1)
    static let black = RGB(r: 0, g: 0, b: 0)

    var uiColor: UIColor { UIColor(red: r, green: g, blue: b, alpha: 1) }

    /// WCAG relative luminance.
    var luminance: Double {
        func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    func contrast(with other: RGB) -> Double {
        let (a, b) = (luminance, other.luminance)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    func mixed(with other: RGB, by t: Double) -> RGB {
        RGB(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
    }

    /// This colour moved toward `target` in small steps until it reaches
    /// `ratio` against `page` — 4.5:1 is WCAG's bar for text, 3:1 for a
    /// shape. A colour that already clears it comes back unchanged.
    func reaching(_ ratio: Double, against page: RGB, movingToward target: RGB) -> RGB {
        var step = 0.0
        var out = self
        while out.contrast(with: page) < ratio, step < 1 {
            step += 0.05
            out = mixed(with: target, by: step)
        }
        return out
    }
}
