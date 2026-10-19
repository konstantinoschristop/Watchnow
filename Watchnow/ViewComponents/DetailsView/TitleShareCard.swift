//
//  TitleShareCard.swift
//  Watchnow
//
//  The image the details screen's Share button sends: the poster over a
//  blurred, tinted wash of the title's own artwork, the title and its
//  facts, where it streams, and a small Watchnow mark. The App Store link
//  rides along as the message (`ShareMessage`), so whoever receives it can
//  get the app in one tap.
//
//  Rendered with `ImageRenderer`, so it is plain SwiftUI with every image
//  already loaded — no `AsyncImage`, nothing UIKit-backed. Always dark: it
//  is going to someone else's chat, whose appearance we can't know, and a
//  poster reads best on dark.
//

import SwiftUI

struct TitleShareCard: View {

    let title: String
    let kind: String?
    let year: String?
    let rating: Double?
    let certification: String?
    let genres: [String]
    let poster: UIImage?
    let backdrop: UIImage?
    let tint: Color
    let providerLogos: [UIImage]

    static let size = CGSize(width: 360, height: 480)

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)

            posterView

            VStack(spacing: 6) {
                if let kind {
                    Text(kind.uppercased(with: .current))
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.4)
                        .opacity(0.75)
                }
                Text(title)
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                meta
                if !genres.isEmpty {
                    Text(genres.prefix(3).joined(separator: " · "))
                        .font(.system(size: 13, weight: .medium))
                        .opacity(0.75)
                        .lineLimit(1)
                }
            }

            if !providerLogos.isEmpty {
                HStack(spacing: 8) {
                    Text("Available on", comment: "Details section: streaming services carrying the title")
                        .font(.system(size: 12, weight: .semibold))
                        .opacity(0.8)
                    ForEach(Array(providerLogos.prefix(4).enumerated()), id: \.offset) { _, logo in
                        Image(uiImage: logo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 26, height: 26)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                Text(verbatim: "Watchnow")
                    .font(.system(size: 13, weight: .bold))
            }
            .opacity(0.9)
        }
        .padding(24)
        .foregroundStyle(.white)
        .frame(width: Self.size.width, height: Self.size.height)
        .background { background }
        .environment(\.colorScheme, .dark)
    }

    private var posterView: some View {
        Group {
            if let poster {
                Image(uiImage: poster)
                    .resizable()
                    .scaledToFill()
            } else {
                tint.opacity(0.6)
            }
        }
        .frame(width: 148, height: 222)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
    }

    private var meta: some View {
        HStack(spacing: 6) {
            if let rating, rating > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(RatingStyle.tint(for: rating))
                    Text(rating.ratingText)
                }
            }
            if let year, !year.isEmpty {
                if rating != nil { Text(verbatim: "·").opacity(0.6) }
                Text(year)
            }
            if let certification, !certification.isEmpty {
                Text(certification)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(.white.opacity(0.75), lineWidth: 1)
                    }
            }
        }
        .font(.system(size: 14, weight: .semibold))
        .opacity(0.92)
    }

    private var background: some View {
        ZStack {
            tint
            if let art = backdrop ?? poster {
                Image(uiImage: art)
                    .resizable()
                    .scaledToFill()
                    .frame(width: Self.size.width, height: Self.size.height)
                    .clipped()
                    .blur(radius: 26, opaque: true)
                    .opacity(0.6)
            }
            LinearGradient(colors: [.black.opacity(0.1), .black.opacity(0.7)],
                           startPoint: .top, endPoint: .bottom)
        }
    }

    /// The card as a 3× image, ready to share.
    @MainActor
    func render() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 3
        return renderer.uiImage
    }
}

// MARK: - Message

/// The text that travels with a share.
enum ShareMessage {

    /// Watchnow on the App Store. Region-neutral: Apple sends each visitor
    /// to their own country's store.
    static let appStoreURL = URL(string: "https://apps.apple.com/app/id6761653452")!

    /// "Breaking Bad — found on Watchnow", then the App Store link.
    static func text(title: String) -> String {
        String(localized: "\(title) — found on Watchnow",
               comment: "Share message, followed by the App Store link. The name is a movie or series.")
            + "\n" + appStoreURL.absoluteString
    }
}
