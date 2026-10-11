//
//  BaseNetworkService.swift
//  Watchnow
//
//  Created by k.christopoulos on 20/9/25.
//

import Foundation

class BaseNetworkService: @unchecked Sendable {
    
    private let session: URLSession
    private let decoder: JSONDecoder

    /// Shared session with a timeout a person would actually wait out.
    ///
    /// `URLSession.shared` defaults to a 60-second request timeout, which is
    /// far too long for a fetch a screen is blocked on: the user taps, gets a
    /// placeholder, and has concluded the screen is broken long before the
    /// request gives up and the retryable error state appears. Twenty seconds
    /// is still generous for a slow cellular connection and turns a stall
    /// into something the UI can report.
    ///
    /// Also worth knowing: the default `httpMaximumConnectionsPerHost` is 6,
    /// and every TMDB call in the app goes to the same host. A screen that
    /// fans out eight requests at once is already queueing some of them, so a
    /// bounded timeout is what stops a queued request from stalling behind a
    /// slow one indefinitely.
    static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 40
        return URLSession(configuration: configuration)
    }()

    init(session: URLSession = BaseNetworkService.defaultSession,
         decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.decoder = decoder
    }

    // Common request method
    func request<T: Decodable>(urlString: String) async throws -> T {
        let data = try await self.data(from: urlString)
        return try decoder.decode(T.self, from: await backfilled(data, from: urlString))
    }

    /// A translated response with holes in it, patched from the English one.
    /// The English request is made only when there's something to fill, and
    /// failing it keeps the translated response as it was.
    private func backfilled(_ data: Data, from urlString: String) async -> Data {
        let language = API.languageCode
        guard let englishURL = API.englishFallback(for: urlString),
              var localized = try? JSONSerialization.jsonObject(with: data),
              TranslationBackfill.hasGaps(localized, languageCode: language)
        else { return data }

        if let englishData = try? await self.data(from: englishURL),
           let english = try? JSONSerialization.jsonObject(with: englishData) {
            localized = TranslationBackfill.merge(localized, english: english, languageCode: language)
        }
        localized = await backfillRemainingTitles(in: localized)
        return (try? JSONSerialization.data(withJSONObject: localized)) ?? data
    }

    /// The most titles of one list looked up one by one.
    private static let individualLookupLimit = 10

    /// Titles in a list still missing their translation after the English
    /// list was merged in, filled from each title's own English details.
    ///
    /// The English list can't always fill them: TMDB's `/similar` isn't
    /// stable from one request to the next, and two calls a second apart
    /// can share none of their twenty titles. A Greek "Similar" row then
    /// kept its Japanese and Swedish originals.
    private func backfillRemainingTitles(in json: Any) async -> Any {
        let language = API.languageCode
        guard var object = json as? [String: Any] else { return json }
        for key in ["results", "parts"] {
            guard let items = object[key] as? [Any] else { continue }
            // Index → English details URL, for the items that still have a gap.
            let lookups: [(Int, String)] = items.enumerated().compactMap { index, item in
                guard let title = item as? [String: Any],
                      TranslationBackfill.hasGaps(title, languageCode: language),
                      let id = title["id"] as? Int else { return nil }
                let type = title["media_type"] as? String ?? (title["title"] != nil ? "movie" : "tv")
                guard type == "movie" || type == "tv",
                      let url = API.englishFallback(for: API.Common.details(screenType: type, id: String(id)))
                else { return nil }
                return (index, url)
            }
            guard !lookups.isEmpty else { continue }

            let found = await withTaskGroup(of: (Int, Data?).self) { group in
                for (index, url) in lookups.prefix(Self.individualLookupLimit) {
                    group.addTask { (index, try? await self.data(from: url)) }
                }
                var found: [Int: Data] = [:]
                for await (index, data) in group { found[index] = data }
                return found
            }
            var filled = items
            for (index, data) in found {
                guard let english = try? JSONSerialization.jsonObject(with: data) else { continue }
                filled[index] = TranslationBackfill.merge(items[index], english: english, languageCode: language)
            }
            object[key] = filled
        }
        return object
    }

    private func data(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        return data
    }

    /// The fewest titles a regional list can have before the worldwide one
    /// replaces it: one TMDB page.
    private static let regionalMinimum = 20

    /// A list scoped to the device's region, or the worldwide one when TMDB
    /// knows of too few titles there. Its release data is thin outside the
    /// big markets — Greece has 5 upcoming films on it, against 123 for the
    /// US — and a five-card row reads as broken rather than local.
    ///
    /// Decided per page from the regional `total_results`, so every page of
    /// a list comes from the same source without anyone keeping track.
    ///
    /// The regional page is only backfilled once it's known to be kept.
    func requestRegional(_ urlString: (_ region: String?) -> String) async throws -> GenericResultResponse {
        let regionalURL = urlString(API.region)
        let data = try await self.data(from: regionalURL)
        let regional = try decoder.decode(GenericResultResponse.self, from: data)
        guard (regional.total_results ?? 0) < Self.regionalMinimum else {
            return try decoder.decode(GenericResultResponse.self, from: await backfilled(data, from: regionalURL))
        }
        return try await request(urlString: urlString(nil))
    }
}

/// Fills the holes TMDB leaves in a translated response from the English one.
///
/// Asked for a language a title has no translation in, TMDB does not fall
/// back to English. The overview comes back empty and the title in the
/// title's *original* language: in Greek, 12 of a day's 20 trending series
/// arrived as Korean, Japanese or Chinese names with no description, where
/// English has "LINK CLICK" and "The Apothecary Diaries".
///
/// Works on the raw JSON so every endpoint is covered at once. Objects are
/// paired up by TMDB id (and media type, which `search/multi` mixes), and
/// only the gaps are taken from English: anything the translation does have
/// is kept.
enum TranslationBackfill {

    /// Free text that comes back empty when there's no translation.
    private static let textFields = ["overview", "tagline", "biography"]
    /// The ones whose absence is worth a second request. Most titles have no
    /// tagline in English either, so an empty one is filled when English is
    /// fetched anyway but never triggers the fetch.
    private static let gapTriggers: Set<String> = ["overview", "biography"]
    /// Each title field, and the field holding the original title it falls
    /// back to.
    private static let titleFields = [("title", "original_title"), ("name", "original_name")]

    /// Whether anything in `json` is missing its translation.
    static func hasGaps(_ json: Any, languageCode: String) -> Bool {
        switch json {
        case let object as [String: Any]:
            return gappedFields(in: object, languageCode: languageCode).contains { !textFields.contains($0) || gapTriggers.contains($0) }
                || object.values.contains { hasGaps($0, languageCode: languageCode) }
        case let array as [Any]:
            return array.contains { hasGaps($0, languageCode: languageCode) }
        default:
            return false
        }
    }

    /// `localized` with each gap filled from its counterpart in `english`.
    static func merge(_ localized: Any, english: Any, languageCode: String) -> Any {
        switch (localized, english) {
        case (var object as [String: Any], let fallback as [String: Any]):
            for field in gappedFields(in: object, languageCode: languageCode) {
                if let value = fallback[field] as? String, !value.isEmpty {
                    object[field] = value
                }
            }
            for (key, value) in object {
                if let counterpart = fallback[key] {
                    object[key] = merge(value, english: counterpart, languageCode: languageCode)
                }
            }
            return object
        case (let array as [Any], let fallback as [Any]):
            let counterparts = Dictionary(fallback.compactMap { element in
                identity(of: element).map { ($0, element) }
            }, uniquingKeysWith: { first, _ in first })
            return array.map { element in
                guard let key = identity(of: element), let counterpart = counterparts[key] else { return element }
                return merge(element, english: counterpart, languageCode: languageCode)
            }
        default:
            return localized
        }
    }

    /// The fields of one object that are missing their translation.
    ///
    /// A title counts only when it's the original title of something first
    /// made in neither the device language nor English: an English film's
    /// original title *is* its English one, so asking again would change
    /// nothing. Without `original_language` — people, genres, episodes —
    /// there's no telling a fallback from a real name, and titles are left.
    private static func gappedFields(in object: [String: Any], languageCode: String) -> [String] {
        var fields = textFields.filter { (object[$0] as? String)?.isEmpty == true }
        if let original = object["original_language"] as? String,
           original != languageCode, original != "en" {
            for (title, originalTitle) in titleFields {
                if let value = object[title] as? String, value == object[originalTitle] as? String {
                    fields.append(title)
                }
            }
        }
        return fields
    }

    private static func identity(of element: Any) -> String? {
        guard let object = element as? [String: Any], let id = object["id"] else { return nil }
        return "\(object["media_type"] ?? "")/\(id)"
    }
}
