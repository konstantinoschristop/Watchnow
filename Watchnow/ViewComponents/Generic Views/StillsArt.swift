//
//  StillsArt.swift
//  Watchnow
//
//  The heroes' picture: a title's own film stills played as a silent
//  trailer, each moving while it's on screen and dissolving into the next,
//  in place of a single poster.
//
//  How a still moves is being chosen between four takes, switched in
//  Settings' debug section ("Stills motion"):
//
//   - Still: no motion at all — the title's best still, held. The default:
//     a header that never stops moving drew the eye from everything under
//     it.
//   - Pan: a slow drift across the still's width.
//   - Push-in: a slow zoom toward the still's centre, no sideways travel.
//   - Spatial: the people lifted off the still by Vision, the background
//     softly out of focus behind them, and the two drifting a few points
//     apart — the still reads as three-dimensional, like a spatial photo.
//
//  All of it is Core Animation on the render server, so a hero that never
//  stops moving costs the app's main thread nothing; a SwiftUI animation of
//  the same moves would update the view every frame for as long as they ran.
//

import SwiftUI
import UIKit
import Vision
import CoreImage
import ImageIO
import Network
import os
import Kingfisher

enum StillsMotion: String, CaseIterable, Identifiable {
    case still, pan, pushIn, spatial

    var id: Self { self }

    /// Debug-only labels; never shown in a release build.
    var debugName: String {
        switch self {
        case .still: return "Still"
        case .pan: return "Pan"
        case .pushIn: return "Push-in"
        case .spatial: return "Spatial"
        }
    }

    static let storageKey = "debugStillsMotion"
}

/// A title's stills, one after another, each moving while it's on screen
/// and dissolving into the next. Still when it isn't the slide on screen,
/// when the slideshow is paused, and under Reduce Motion — and always with
/// the `.still` motion, which shows only the first.
struct StillsArt: UIViewRepresentable {
    let urls: [URL]
    let isActive: Bool
    var motion: StillsMotion = .still
    var onImage: (UIImage) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeUIView(context: Context) -> StillsView {
        StillsView()
    }

    func updateUIView(_ view: StillsView, context: Context) {
        view.onImage = onImage
        view.configure(urls: urls, isActive: isActive && !reduceMotion, motion: motion)
    }

    final class StillsView: UIView {
        var onImage: (UIImage) -> Void = { _ in }

        /// The still on show, and the one the next comes up in. They swap
        /// roles at each dissolve.
        private var current = StillLayer()
        private var spare = StillLayer()
        private var urls: [URL] = []
        private var index = 0
        private var isActive = false
        private var motion: StillsMotion = .still
        private var timer: Timer?
        private var panLeft = false
        private var laidOutSize: CGSize = .zero

        /// How long each still shows, and how long the dissolve takes. Two
        /// stills fit in a title's six seconds on the hero, and the next
        /// change would fall after the title has moved on, so a leaving
        /// title never starts a dissolve on its way out.
        private let dwell: TimeInterval = 3.2
        private let dissolve: TimeInterval = 0.9

        override init(frame: CGRect) {
            super.init(frame: frame)
            clipsToBounds = true
            backgroundColor = .black
            addSubview(spare)
            addSubview(current)
            spare.alpha = 0
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        override func layoutSubviews() {
            super.layoutSubviews()
            current.frame = bounds
            spare.frame = bounds
            // A move worked out before the view had a size goes nowhere;
            // start it again now there is one.
            guard bounds.size != laidOutSize else { return }
            laidOutSize = bounds.size
            startMoving()
        }

        /// Called on every SwiftUI update; acts only on a change. New stills
        /// — the textless ones arriving after the poster was shown — start
        /// over from the first; any change restarts the rotation.
        func configure(urls: [URL], isActive: Bool, motion: StillsMotion) {
            let stillsChanged = urls != self.urls
            // `.still` shows the still cut to the hero (`HeroStillProcessor`);
            // the moving takes need all of it to travel across.
            let cropChanged = (motion == .still) != (self.motion == .still)
            guard stillsChanged || isActive != self.isActive || motion != self.motion else { return }
            self.urls = urls
            self.isActive = isActive
            self.motion = motion
            if stillsChanged || cropChanged {
                index = 0
                // Over a still already showing, the new one dissolves in.
                show(at: 0, animated: current.hasImage)
            } else {
                current.applyMotion(motion)
            }
            restartRotation()
        }

        private func restartRotation() {
            timer?.invalidate()
            timer = nil
            startMoving()
            guard isActive, motion != .still, urls.count > 1 else { return }
            timer = Timer.scheduledTimer(withTimeInterval: dwell, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.advance() }
            }
        }

        /// Sets the still on show moving, once there's both a still and a
        /// size; otherwise leaves it at rest.
        private func startMoving() {
            current.stop()
            guard isActive, motion != .still, current.hasImage, bounds.width > 0 else { return }
            panLeft.toggle()
            current.move(motion, duration: dwell + dissolve * 2, panLeft: panLeft)
        }

        private func advance() {
            guard !urls.isEmpty else { return }
            index = (index + 1) % urls.count
            show(at: index, animated: true)
        }

        private func show(at index: Int, animated: Bool) {
            guard urls.indices.contains(index) else { return }
            let url = urls[index]
            var options: KingfisherOptionsInfo = [.cacheOriginalImage]
            if motion == .still { options.append(.processor(HeroStillProcessor())) }
            KingfisherManager.shared.retrieveImage(with: url, options: options) { [weak self] result in
                guard case .success(let value) = result else { return }
                let image = value.image
                // Kingfisher calls back on the main queue.
                MainActor.assumeIsolated { self?.present(image, from: url, at: index, animated: animated) }
            }
        }

        private func present(_ image: UIImage, from url: URL, at index: Int, animated: Bool) {
            if index == 0 { onImage(image) }
            guard animated else {
                // The first still fades up out of the hero's black rather
                // than landing in a single frame.
                let isFirst = !current.hasImage
                current.setStill(image, url: url, motion: motion)
                startMoving()
                if isFirst {
                    current.alpha = 0
                    UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseOut]) {
                        self.current.alpha = 1
                    }
                }
                return
            }
            // The next still comes up over the current one, already moving,
            // and the two swap roles once it's covered it.
            let incoming = spare
            incoming.frame = bounds
            incoming.setStill(image, url: url, motion: motion)
            incoming.alpha = 0
            bringSubviewToFront(incoming)
            panLeft.toggle()
            incoming.move(motion, duration: dwell + dissolve * 2, panLeft: panLeft)
            UIView.animate(withDuration: dissolve, delay: 0, options: [.curveEaseInOut]) {
                incoming.alpha = 1
            } completion: { _ in
                self.current.stop()
                self.current.alpha = 0
                self.spare = self.current
                self.current = incoming
            }
        }
    }
}

// MARK: - StillLayer

/// One still, as two layers: the picture, and — for the spatial motion —
/// its subject cut out and laid back over it, with the picture behind
/// softened. The two share a frame so they line up exactly at rest.
@MainActor
final class StillLayer: UIView {
    private let background = UIImageView()
    private let subject = UIImageView()
    private var image: UIImage?
    private var url: URL?

    var hasImage: Bool { image != nil }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        for view in [background, subject] {
            view.contentMode = .scaleAspectFill
            view.clipsToBounds = false
            addSubview(view)
        }
        subject.alpha = 0
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let frame = stillFrame
        // Frames only while nothing is moving them; a move resets its own.
        if background.layer.animation(forKey: "move") == nil { background.frame = frame }
        if subject.layer.animation(forKey: "move") == nil { subject.frame = frame }
    }

    /// The still at the frame's full height, as wide as its shape makes it —
    /// wider than the frame, which is what a pan travels across.
    private var stillFrame: CGRect {
        let aspect = image.map { $0.size.width / max($0.size.height, 1) } ?? 16 / 9
        let height = bounds.height
        let width = max(bounds.width, height * aspect)
        return CGRect(x: (bounds.width - width) / 2, y: 0, width: width, height: height)
    }

    func setStill(_ image: UIImage, url: URL, motion: StillsMotion) {
        self.image = image
        self.url = url
        background.image = image
        subject.image = nil
        subject.alpha = 0
        background.frame = stillFrame
        subject.frame = stillFrame
        applyMotion(motion)
    }

    /// For the spatial motion, swaps in the softened background and the
    /// lifted subject once they've been made — at once if they're cached,
    /// otherwise with a short dissolve when they land. Other motions show
    /// the plain still.
    func applyMotion(_ motion: StillsMotion) {
        guard let image, let url else { return }
        guard motion == .spatial else {
            background.image = image
            subject.alpha = 0
            return
        }
        if let made = SpatialStillStore.shared.cached(url) {
            showSpatial(made, animated: false)
            return
        }
        Task {
            let made = await SpatialStillStore.shared.spatial(for: url, image: image)
            // Still showing the same still?
            guard self.url == url, let made else { return }
            self.showSpatial(made, animated: true)
        }
    }

    private func showSpatial(_ spatial: SpatialStill, animated: Bool) {
        guard let cutout = spatial.subject else { return }
        let apply = {
            self.background.image = spatial.softened
            self.subject.image = cutout
            self.subject.alpha = 1
        }
        if animated {
            UIView.transition(with: self, duration: 0.4, options: [.transitionCrossDissolve, .allowAnimatedContent],
                              animations: apply)
        } else {
            apply()
        }
    }

    /// Starts the still's move. A spatial still with no subject to lift —
    /// or one whose cut-out hasn't landed yet — pushes in instead.
    func move(_ motion: StillsMotion, duration: TimeInterval, panLeft: Bool) {
        background.frame = stillFrame
        subject.frame = stillFrame
        switch motion {
        case .still:
            break
        case .pan:
            let travel = max(0, (stillFrame.width - bounds.width) / 2) * 0.7
            add(from: CATransform3DMakeTranslation(panLeft ? travel : -travel, 0, 0),
                to: CATransform3DScale(CATransform3DMakeTranslation(panLeft ? -travel : travel, 0, 0), 1.06, 1.06, 1),
                to: background, duration: duration)
        case .pushIn:
            add(from: CATransform3DIdentity,
                to: CATransform3DMakeScale(1.12, 1.12, 1),
                to: background, duration: duration)
        case .spatial:
            // Background and subject drift apart: the softened picture one
            // way and a touch larger, the sharp subject the other — the
            // parallax that makes a flat still read as depth. Small, or the
            // blurred subject behind shows round the edges.
            let drift: CGFloat = panLeft ? 7 : -7
            add(from: CATransform3DScale(CATransform3DMakeTranslation(drift, 0, 0), 1.04, 1.04, 1),
                to: CATransform3DScale(CATransform3DMakeTranslation(-drift, 0, 0), 1.09, 1.09, 1),
                to: background, duration: duration)
            add(from: CATransform3DMakeTranslation(-drift * 0.6, 0, 0),
                to: CATransform3DScale(CATransform3DMakeTranslation(drift * 0.6, 0, 0), 1.035, 1.035, 1),
                to: subject, duration: duration)
        }
    }

    func stop() {
        for view in [background, subject] {
            view.layer.removeAnimation(forKey: "move")
            view.layer.transform = CATransform3DIdentity
        }
    }

    private func add(from: CATransform3D, to: CATransform3D, to view: UIView, duration: TimeInterval) {
        let animation = CABasicAnimation(keyPath: "transform")
        animation.fromValue = from
        animation.toValue = to
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        view.layer.add(animation, forKey: "move")
    }
}

// MARK: - Spatial stills

/// A still made spatial: the picture softened, as if out of focus, and its
/// subject lifted out sharp. No subject — a landscape, a crowd too small to
/// lift — means no cut-out, and the still pushes in instead.
struct SpatialStill: @unchecked Sendable {
    let softened: UIImage
    let subject: UIImage?
}

/// Spatial stills by URL, made once each, off the main actor. Vision's
/// subject lifting runs on device in a fraction of a second.
@MainActor
final class SpatialStillStore {
    static let shared = SpatialStillStore()

    private var made: [URL: SpatialStill] = [:]
    private var inFlight: [URL: Task<SpatialStill?, Never>] = [:]

    func cached(_ url: URL) -> SpatialStill? {
        made[url]
    }

    func spatial(for url: URL, image: UIImage) async -> SpatialStill? {
        if let known = made[url] { return known }
        if let pending = inFlight[url] { return await pending.value }
        let task = Task.detached(priority: .utility) { SpatialStill.make(from: image) }
        inFlight[url] = task
        let result = await task.value
        inFlight[url] = nil
        if let result { made[url] = result }
        return result
    }
}

extension SpatialStill {
    nonisolated static func make(from image: UIImage) -> SpatialStill? {
        guard let cgImage = image.cgImage else { return nil }
        let context = CIContext()
        let source = CIImage(cgImage: cgImage)

        // Softened: blurred with its edges clamped, so the blur doesn't
        // fade to transparent at the borders.
        guard let blurred = CIFilter(name: "CIGaussianBlur",
                                     parameters: [kCIInputImageKey: source.clampedToExtent(),
                                                  kCIInputRadiusKey: 9])?.outputImage?.cropped(to: source.extent),
              let softened = context.createCGImage(blurred, from: source.extent) else { return nil }

        var subject: UIImage?
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        if (try? handler.perform([request])) != nil,
           let observation = request.results?.first, !observation.allInstances.isEmpty,
           let buffer = try? observation.generateMaskedImage(ofInstances: observation.allInstances,
                                                            from: handler,
                                                            croppedToInstancesExtent: false),
           let cut = context.createCGImage(CIImage(cvPixelBuffer: buffer),
                                           from: CGRect(x: 0, y: 0,
                                                        width: CVPixelBufferGetWidth(buffer),
                                                        height: CVPixelBufferGetHeight(buffer))) {
            subject = UIImage(cgImage: cut, scale: image.scale, orientation: .up)
        }
        return SpatialStill(softened: UIImage(cgImage: softened, scale: image.scale, orientation: .up),
                            subject: subject)
    }
}

// MARK: - Hero stills

/// Where a hero's still comes from: full size on a connection that isn't
/// metered, cut down to the hero by `HeroStillProcessor`, and 1280 wide
/// otherwise. A 16:9 still cut to a phone-tall hero keeps a third of its
/// width, so from 1280 the hero shows a 720-pixel-tall picture stretched
/// over nearly two thousand — the softness that made some heroes look off.
/// The full size is eight times the download, which is why it waits for
/// Wi-Fi.
enum HeroStill {
    static func url(path: String) -> URL? {
        let width: API.ImageWidth = NetworkConditions.shared.isUnmetered ? .original : .heroBackdrop
        return URL(string: API.Common.imageUrl(imageId: path, width: width))
    }
}

/// Whether the connection is one to spend on full-size art: not cellular or
/// a personal hotspot, and not in Low Data Mode. Unknown until the first
/// reading, which takes a moment, and taken as metered until then.
final class NetworkConditions: @unchecked Sendable {
    static let shared = NetworkConditions()

    private let monitor = NWPathMonitor()
    private let unmetered = OSAllocatedUnfairLock(initialState: false)

    var isUnmetered: Bool { unmetered.withLock { $0 } }

    private init() {
        let unmetered = unmetered
        monitor.pathUpdateHandler = { path in
            let isUnmetered = path.status == .satisfied && !path.isExpensive && !path.isConstrained
            unmetered.withLock { $0 = isUnmetered }
        }
        monitor.start(queue: DispatchQueue(label: "watchnow.network-conditions", qos: .utility))
    }
}

/// A still cut to the hero's shape around its subject, at the size the hero
/// shows it.
///
/// The hero is portrait and the stills are 16:9, so the hero shows the
/// middle third of each — and the middle third is often a wall, with the
/// face it was framed on cut at the edge. This finds the faces in the
/// frame (or, with none, what draws the eye) and centres the cut on them.
/// Decoded already downsized, so a full-size still never sits in memory at
/// full size. Runs on Kingfisher's processing queue, and the result is
/// cached, so each still is worked out once.
struct HeroStillProcessor: ImageProcessor {
    /// Width over height kept: a little wider than any phone's hero, which
    /// trims the rest evenly at the sides, keeping the subject in the middle.
    static let aspect: CGFloat = 0.75
    /// The cut's height in pixels: the hero on a 3x Pro Max, near enough.
    static let pixelHeight: CGFloat = 1600

    let identifier = "watchnow.hero-still.v1"

    func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        let decoded: CGImage?
        switch item {
        case .data(let data): decoded = Self.decode(data)
        case .image(let image): decoded = image.cgImage.flatMap(Self.downsized)
        }
        guard let decoded else { return nil }
        return UIImage(cgImage: Self.cropped(decoded), scale: 1, orientation: .up)
    }

    /// The still decoded at no more than `pixelHeight` tall.
    private static func decode(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
              height > 0 else { return nil }
        let longest = max(width, height) * min(1, Double(pixelHeight) / height)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(longest.rounded()),
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// An already-decoded still, brought down to `pixelHeight` if it's taller.
    private static func downsized(_ image: CGImage) -> CGImage? {
        let height = CGFloat(image.height)
        guard height > pixelHeight else { return image }
        let size = CGSize(width: (CGFloat(image.width) * pixelHeight / height).rounded(), height: pixelHeight)
        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return image }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: size))
        return context.makeImage()
    }

    /// The full height, `aspect` wide, centred on the subject as far as the
    /// still's edges allow.
    private static func cropped(_ image: CGImage) -> CGImage {
        let width = CGFloat(image.width), height = CGFloat(image.height)
        let cropWidth = (height * aspect).rounded()
        guard cropWidth < width else { return image }
        let focus = subjectCentre(of: image, keeping: cropWidth / width) ?? 0.5
        let x = min(max((focus * width - cropWidth / 2).rounded(), 0), width - cropWidth)
        return image.cropping(to: CGRect(x: x, y: 0, width: cropWidth, height: height)) ?? image
    }

    /// Where across the still its subject is, 0 to 1: the faces in it —
    /// together if they fit in the cut, else the biggest — or with none,
    /// what draws the eye. Faces a fraction the size of the biggest are a
    /// crowd behind the subject, and don't count.
    private static func subjectCentre(of image: CGImage, keeping fraction: CGFloat) -> CGFloat? {
        let faces = VNDetectFaceRectanglesRequest()
        let attention = VNGenerateAttentionBasedSaliencyImageRequest()
        try? VNImageRequestHandler(cgImage: image, orientation: .up).perform([faces, attention])

        let boxes = (faces.results ?? []).map(\.boundingBox)
        if let biggest = boxes.max(by: { $0.width * $0.height < $1.width * $1.height }) {
            let subjects = boxes.filter { $0.width * $0.height >= biggest.width * biggest.height * 0.15 }
            let together = subjects.dropFirst().reduce(subjects[0]) { $0.union($1) }
            return together.width <= fraction * 0.9 ? together.midX : biggest.midX
        }
        let salient = (attention.results?.first?.salientObjects ?? []).map(\.boundingBox)
        guard let first = salient.first else { return nil }
        return salient.dropFirst().reduce(first) { $0.union($1) }.midX
    }
}
