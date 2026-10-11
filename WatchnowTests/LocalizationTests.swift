//
//  LocalizationTests.swift
//  WatchnowTests
//
//  Unit coverage for requesting TMDB data in the device language: the
//  mapping from an iOS language identifier to TMDB's `language` parameter,
//  and `TranslationBackfill`, which fills a translation's gaps from English.
//
//  No network — backfill inputs are hand-built fixtures shaped like the
//  responses TMDB actually returns for a Greek request.
//

import XCTest
@testable import Watchnow

final class TMDBLanguageTests: XCTestCase {

    func testLanguageAndRegionPassThrough() {
        XCTAssertEqual(API.tmdbLanguage(for: "el-GR"), "el-GR")
        XCTAssertEqual(API.tmdbLanguage(for: "pt-BR"), "pt-BR")
        XCTAssertEqual(API.tmdbLanguage(for: "en-US"), "en-US")
    }

    func testLanguageWithoutRegionStaysBare() {
        XCTAssertEqual(API.tmdbLanguage(for: "el"), "el")
    }

    func testChineseIsKeyedByRegionNotScript() {
        XCTAssertEqual(API.tmdbLanguage(for: "zh-Hans-CN"), "zh-CN")
        XCTAssertEqual(API.tmdbLanguage(for: "zh-Hans"), "zh-CN")
        XCTAssertEqual(API.tmdbLanguage(for: "zh-Hant"), "zh-TW")
        XCTAssertEqual(API.tmdbLanguage(for: "zh-Hant-TW"), "zh-TW")
        XCTAssertEqual(API.tmdbLanguage(for: "zh-HK"), "zh-HK")
        XCTAssertEqual(API.tmdbLanguage(for: "zh-Hant-MO"), "zh-HK")
    }

    func testLatinAmericanSpanishMapsToMexico() {
        XCTAssertEqual(API.tmdbLanguage(for: "es-419"), "es-MX")
    }

    func testNoPreferredLanguageFallsBackToEnglish() {
        XCTAssertEqual(API.tmdbLanguage(for: nil), "en-US")
    }
}

final class TranslationBackfillTests: XCTestCase {

    private func json(_ text: String) -> Any {
        try! JSONSerialization.jsonObject(with: Data(text.utf8))
    }

    private func results(_ merged: Any) -> [[String: Any]] {
        (merged as! [String: Any])["results"] as! [[String: Any]]
    }

    // MARK: - Gaps

    func testEmptyOverviewIsAGap() {
        let localized = json(#"{"results": [{"id": 1, "overview": "", "original_language": "en", "title": "Fight Club", "original_title": "Fight Club"}]}"#)
        XCTAssertTrue(TranslationBackfill.hasGaps(localized, languageCode: "el"))
    }

    func testUntranslatedForeignTitleIsAGap() {
        let localized = json(#"{"results": [{"id": 1, "overview": "Κάτι.", "original_language": "ja", "name": "薬屋のひとりごと", "original_name": "薬屋のひとりごと"}]}"#)
        XCTAssertTrue(TranslationBackfill.hasGaps(localized, languageCode: "el"))
    }

    /// An English film's original title is its English title: asking TMDB
    /// in English would change nothing.
    func testEnglishOriginalTitleIsNotAGap() {
        let localized = json(#"{"results": [{"id": 550, "overview": "Ο υλικός κορεσμός…", "original_language": "en", "title": "Fight Club", "original_title": "Fight Club"}]}"#)
        XCTAssertFalse(TranslationBackfill.hasGaps(localized, languageCode: "el"))
    }

    /// A Greek film keeps its Greek title on a Greek device.
    func testOriginalTitleInTheDeviceLanguageIsNotAGap() {
        let localized = json(#"{"results": [{"id": 2, "overview": "Κάτι.", "original_language": "el", "title": "Ο Κυνόδοντας", "original_title": "Ο Κυνόδοντας"}]}"#)
        XCTAssertFalse(TranslationBackfill.hasGaps(localized, languageCode: "el"))
    }

    /// People have no `original_language`, so a name matching its
    /// `original_name` says nothing about a missing translation.
    func testPeopleNamesAreNotGaps() {
        let localized = json(#"{"cast": [{"id": 287, "name": "Brad Pitt", "original_name": "Brad Pitt", "character": "Tyler Durden"}]}"#)
        XCTAssertFalse(TranslationBackfill.hasGaps(localized, languageCode: "el"))
    }

    func testGapsAreFoundInNestedObjects() {
        let localized = json(#"{"name": "Breaking Bad", "episodes": [{"id": 62085, "name": "Επεισόδιο-πιλότος", "overview": ""}]}"#)
        XCTAssertTrue(TranslationBackfill.hasGaps(localized, languageCode: "el"))
    }

    /// Most titles have no tagline in English either, so an empty one alone
    /// isn't worth a second request.
    func testEmptyTaglineAloneIsNotAGap() {
        let localized = json(#"{"id": 1, "overview": "Κάτι.", "tagline": "", "original_language": "en", "title": "Fight Club", "original_title": "Fight Club"}"#)
        XCTAssertFalse(TranslationBackfill.hasGaps(localized, languageCode: "el"))
    }

    /// …but it's filled when English is fetched for something else.
    func testEmptyTaglineIsFilledAlongsideAnotherGap() {
        let localized = json(#"{"id": 1, "overview": "", "tagline": ""}"#)
        let english = json(#"{"id": 1, "overview": "One.", "tagline": "Mischief. Mayhem. Soap."}"#)

        XCTAssertTrue(TranslationBackfill.hasGaps(localized, languageCode: "el"))
        let merged = TranslationBackfill.merge(localized, english: english, languageCode: "el") as! [String: Any]
        XCTAssertEqual(merged["tagline"] as? String, "Mischief. Mayhem. Soap.")
    }

    // MARK: - Merge

    func testMergeFillsOnlyTheGaps() {
        let localized = json(#"""
        {"results": [
            {"id": 1, "original_language": "ko", "name": "닥터X: 하얀 마피아의 시대", "original_name": "닥터X: 하얀 마피아의 시대", "overview": ""},
            {"id": 2, "original_language": "en", "name": "Breaking Bad", "original_name": "Breaking Bad", "overview": "Ο καθηγητής…"}
        ]}
        """#)
        let english = json(#"""
        {"results": [
            {"id": 1, "original_language": "ko", "name": "Doctor X: Mafia in White", "original_name": "닥터X: 하얀 마피아의 시대", "overview": "A surgeon…"},
            {"id": 2, "original_language": "en", "name": "Breaking Bad", "original_name": "Breaking Bad", "overview": "A chemistry teacher…"}
        ]}
        """#)

        let merged = results(TranslationBackfill.merge(localized, english: english, languageCode: "el"))

        XCTAssertEqual(merged[0]["name"] as? String, "Doctor X: Mafia in White")
        XCTAssertEqual(merged[0]["overview"] as? String, "A surgeon…")
        // The translation the second title does have is kept.
        XCTAssertEqual(merged[1]["overview"] as? String, "Ο καθηγητής…")
    }

    func testMergePairsByIDNotPosition() {
        let localized = json(#"{"results": [{"id": 1, "overview": ""}, {"id": 2, "overview": ""}]}"#)
        let english = json(#"{"results": [{"id": 2, "overview": "Two"}, {"id": 1, "overview": "One"}]}"#)

        let merged = results(TranslationBackfill.merge(localized, english: english, languageCode: "el"))

        XCTAssertEqual(merged.map { $0["overview"] as? String }, ["One", "Two"])
    }

    /// `search/multi` mixes movies and series, and their ids overlap.
    func testMergeKeepsMediaTypesApart() {
        let localized = json(#"{"results": [{"id": 550, "media_type": "tv", "overview": ""}]}"#)
        let english = json(#"{"results": [{"id": 550, "media_type": "movie", "overview": "The movie"}, {"id": 550, "media_type": "tv", "overview": "The series"}]}"#)

        let merged = results(TranslationBackfill.merge(localized, english: english, languageCode: "el"))

        XCTAssertEqual(merged[0]["overview"] as? String, "The series")
    }

    func testMergeFillsNestedObjects() {
        let localized = json(#"{"overview": "Κάτι.", "episodes": [{"id": 62085, "overview": ""}]}"#)
        let english = json(#"{"overview": "Something.", "episodes": [{"id": 62085, "overview": "Walter White…"}]}"#)

        let merged = TranslationBackfill.merge(localized, english: english, languageCode: "el") as! [String: Any]
        let episodes = merged["episodes"] as! [[String: Any]]

        XCTAssertEqual(merged["overview"] as? String, "Κάτι.")
        XCTAssertEqual(episodes[0]["overview"] as? String, "Walter White…")
    }

    /// A title English doesn't know either stays as TMDB sent it.
    func testMergeLeavesGapsEnglishCannotFill() {
        let localized = json(#"{"results": [{"id": 1, "tagline": "", "overview": ""}]}"#)
        let english = json(#"{"results": [{"id": 1, "tagline": "", "overview": "One"}]}"#)

        let merged = results(TranslationBackfill.merge(localized, english: english, languageCode: "el"))

        XCTAssertEqual(merged[0]["tagline"] as? String, "")
    }

    func testMergeKeepsEverythingElse() {
        let localized = json(#"{"results": [{"id": 1, "overview": "", "vote_average": 8.438, "adult": false, "genre_ids": [18, 53], "poster_path": null}], "total_pages": 3}"#)
        let english = json(#"{"results": [{"id": 1, "overview": "One", "vote_average": 8.438, "adult": false, "genre_ids": [18, 53], "poster_path": null}], "total_pages": 3}"#)

        let data = try! JSONSerialization.data(withJSONObject: TranslationBackfill.merge(localized, english: english, languageCode: "el"))
        let response = try! JSONDecoder().decode(GenericResultResponse.self, from: data)

        XCTAssertEqual(response.total_pages, 3)
        XCTAssertEqual(response.results.first?.overview, "One")
        XCTAssertEqual(response.results.first?.vote_average, 8.438)
        XCTAssertEqual(response.results.first?.genre_ids, [18, 53])
    }
}
