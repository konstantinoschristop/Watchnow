//
//  TitleLogoStore.swift
//  Watchnow
//
//  Official title logos for the heroes: a film's or a show's own lettering,
//  in place of its name set in our type — and, from the same request, the
//  title's *textless* art: a poster with no title printed on it, and stills
//  from the film. A logo over a poster that already carries its title says
//  the name twice; over clean art it's how the streaming services do it.
//
//  TMDB carries logos for most titles — all ten trending in Greece when this
//  was written — often in several languages. One request per title, then
//  answered from memory for the rest of the session. A hero prefetches its
//  handful of slides when it appears, so a slide's logo is usually known
//  before the slide is shown.
//

import Foundation
import UIKit

/// `/{type}/{id}/images`: logos, posters and stills.
struct TitleImagesResponse: Decodable, Sendable {
    let logos: [TitleLogoImage]?
    let posters: [TitleLogoImage]?
    let backdrops: [TitleLogoImage]?
}

struct TitleLogoImage: Decodable, Sendable {
    let file_path: String?
    let iso_639_1: String?
    let aspect_ratio: Double?
    let vote_average: Double?
    var vote_count: Int? = nil
    var width: Int? = nil
}

/// Everything the heroes draw a title with, beyond what a list row carries.
struct TitleArt: Equatable, Sendable {
    var logo: TitleLogo?
    /// A poster with no text on it, when TMDB has one.
    var cleanPoster: URL?
    /// Stills from the title, best first, with no text on them — as TMDB
    /// paths, for the hero to fetch at the size the connection allows.
    var stillPaths: [String] = []
}

/// A title's logo, ready to draw.
struct TitleLogo: Equatable, Sendable {
    let url: URL
    /// Width over height. Logos run from squarish to thirteen times as wide
    /// as they are tall.
    let aspectRatio: CGFloat
}

@MainActor
final class TitleLogoStore {

    static let shared = TitleLogoStore()

    struct Key: Hashable, Sendable {
        let id: Int
        let screenType: ScreenTypes
    }

    /// Titles with an answer. Absent means not asked yet. A request that
    /// fails isn't recorded, so the next appearance asks again.
    private var resolved: [Key: TitleArt] = [:]
    private var inFlight: [Key: Task<TitleArt?, Never>] = [:]
    private let service = ServiceInvocation()

    /// The logo answer if there is one yet: `.some(nil)` means "no logo".
    func cached(_ key: Key) -> TitleLogo?? {
        resolved[key].map(\.logo)
    }

    /// All the title's art, if it's been fetched.
    func cachedArt(_ key: Key) -> TitleArt? {
        resolved[key]
    }

    func logo(for key: Key) async -> TitleLogo? {
        await art(for: key)?.logo
    }

    func art(for key: Key) async -> TitleArt? {
        if let known = resolved[key] { return known }
        if let pending = inFlight[key] { return await pending.value }

        let service = service
        let language = API.languageCode
        let task = Task { () -> TitleArt? in
            guard let response = try? await service.fetchImages(screenType: key.screenType, id: key.id) else {
                return nil
            }
            return TitleArt(logo: Self.pick(response.logos ?? [], languageCode: language),
                            cleanPoster: Self.textless(response.posters ?? [], width: .backdrop).first,
                            stillPaths: Array(Self.rankedTextless(response.backdrops ?? []).prefix(4)))
        }
        inFlight[key] = task
        let art = await task.value
        inFlight[key] = nil
        if let art { resolved[key] = art }
        return art
    }

    /// Resolves a hero's slides together, so each one's art is known before
    /// its slide comes round.
    func prefetch(_ keys: [Key]) async {
        await withTaskGroup(of: Void.self) { group in
            for key in keys {
                group.addTask { _ = await self.art(for: key) }
            }
        }
    }

    /// Images with no language — TMDB's mark for art with no text on it —
    /// best first.
    nonisolated static func textless(_ images: [TitleLogoImage], width: API.ImageWidth) -> [URL] {
        rankedTextless(images).compactMap { URL(string: API.Common.imageUrl(imageId: $0, width: width)) }
    }

    /// The paths of `textless` images, best first: full-resolution ones
    /// ahead of any smaller than a hero needs, then by rating — weighed by
    /// how many voted, so one person's ten doesn't outrank the still twenty
    /// people rated seven. Sorted on the bare average, a single stray vote
    /// put an odd frame at the head of the hero.
    nonisolated static func rankedTextless(_ images: [TitleLogoImage]) -> [String] {
        func score(_ image: TitleLogoImage) -> Double {
            let votes = Double(image.vote_count ?? 0)
            return (image.vote_average ?? 0) * votes / (votes + 2)
        }
        func isSharp(_ image: TitleLogoImage) -> Bool {
            // Unknown counts as sharp: test data and older payloads carry no width.
            (image.width ?? .max) >= 1920
        }
        return images
            .filter { $0.iso_639_1 == nil && $0.file_path != nil }
            .enumerated()
            .sorted { a, b in
                if isSharp(a.element) != isSharp(b.element) { return isSharp(a.element) }
                if score(a.element) != score(b.element) { return score(a.element) > score(b.element) }
                return a.offset < b.offset      // TMDB's own order breaks ties
            }
            .compactMap(\.element.file_path)
    }

    /// The device language's logo, else English, else one with no text in
    /// it — and of those, the one TMDB's voters rate highest.
    nonisolated static func pick(_ logos: [TitleLogoImage], languageCode: String) -> TitleLogo? {
        for language in [languageCode, "en", nil] as [String?] {
            let best = logos
                .filter { $0.iso_639_1 == language && $0.file_path != nil }
                .max { ($0.vote_average ?? 0) < ($1.vote_average ?? 0) }
            if let best, let path = best.file_path,
               let url = URL(string: API.Common.imageUrl(imageId: path, width: .logo)) {
                return TitleLogo(url: url, aspectRatio: CGFloat(best.aspect_ratio ?? 3))
            }
        }
        return nil
    }
}

extension UIImage {

    /// How light a logo's ink is, 0 to 1: the luminance of its visible
    /// pixels, weighted by how opaque each is, so the transparent field
    /// around the lettering doesn't count. A dark logo vanishes on the
    /// hero's dark scrim and is drawn in white instead. Renders the image
    /// small; call off the main actor.
    nonisolated var inkLuminance: Double? {
        guard let cgImage else { return nil }
        let side = 24
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let context = CGContext(data: &pixels, width: side, height: side,
                                      bitsPerComponent: 8, bytesPerRow: side * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        var weighted = 0.0
        var coverage = 0.0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[i + 3]) / 255
            guard alpha > 0.05 else { continue }
            // Premultiplied: divide the alpha back out to get the ink's colour.
            let r = Double(pixels[i]) / 255 / alpha
            let g = Double(pixels[i + 1]) / 255 / alpha
            let b = Double(pixels[i + 2]) / 255 / alpha
            weighted += (0.2126 * r + 0.7152 * g + 0.0722 * b) * alpha
            coverage += alpha
        }
        return coverage > 0 ? weighted / coverage : nil
    }
}
