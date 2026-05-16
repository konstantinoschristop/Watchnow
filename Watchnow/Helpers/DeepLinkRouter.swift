//
//  DeepLinkRouter.swift
//  Watchnow
//
//  Central sink for "open a screen X" requests that come from outside the
//  view tree — most importantly, the user tapping a local notification
//  banner that we scheduled for an unreleased title / season / episode.
//
//  Why a singleton ObservableObject and not a passed-down binding:
//    - The `UNUserNotificationCenterDelegate` callback fires from system
//      code with no view-tree context, so it can't write to a `@State`
//      or `@Binding`. It needs a stable, globally addressable sink.
//    - SwiftUI views can observe via `@StateObject`/`@ObservedObject` and
//      react in `.onChange(of: router.pending)`.
//

import Foundation
import Combine

@MainActor
final class DeepLinkRouter: ObservableObject {

    static let shared = DeepLinkRouter()

    @Published var pending: DeepLink?

    private init() {}

    func handle(_ deeplink: DeepLink) {
        pending = deeplink
    }

    /// Decode a userInfo dictionary from a `UNNotificationContent` into a
    /// `DeepLink`. Returns nil when the payload is missing the required
    /// fields — older notifications scheduled before this code shipped
    /// would have no userInfo, which is fine: tapping them just opens the
    /// app without routing.
    nonisolated static func decode(userInfo: [AnyHashable: Any]) -> DeepLink? {
        guard
            let id = userInfo["id"] as? Int,
            let mediaTypeRaw = userInfo["mediaType"] as? String,
            let mediaType = DeepLink.MediaType(rawValue: mediaTypeRaw)
        else {
            return nil
        }
        return DeepLink(id: id, mediaType: mediaType)
    }
}

struct DeepLink: Equatable {

    let id: Int
    let mediaType: MediaType

    enum MediaType: String {
        case movie
        case tv
    }

    /// userInfo payload to embed in a `UNNotificationRequest` so the
    /// `didReceive` handler can rehydrate this struct on tap.
    var userInfo: [String: Any] {
        ["id": id, "mediaType": mediaType.rawValue]
    }
}
