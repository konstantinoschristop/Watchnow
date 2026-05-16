//
//  WatchnowApp.swift
//  Watchnow
//

import SwiftUI
import GoogleMobileAds
import UserMessagingPlatform
import UserNotifications

@main
struct WatchnowApp: App {

    init() {
        // Start the SDK immediately and unconditionally. Per Google's docs,
        // start() should be called at app launch regardless of consent —
        // consent only governs whether ads are personalised, not whether
        // the SDK runs at all. Coupling start() to the consent completion
        // (as the previous version did) means a stalled consent flow blocks
        // ads forever.
        MobileAds.shared.start(completionHandler: nil)

        // Allow notification banners to display while the app is in the
        // foreground — required for the debug-preview button to be useful
        // and improves the UX for real reminders that fire while the user
        // happens to have the app open.
        UNUserNotificationCenter.current().delegate = NotificationCenterDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Run consent flow once the UI is on screen so we have
                    // a guaranteed root view controller for the form.
                    await Self.requestConsent()
                }
        }
    }

    // MARK: - Consent flow

    /// Requests consent info and presents the GDPR consent form if required.
    /// Runs after the UI is on screen so the form has a valid presenter.
    @MainActor
    private static func requestConsent() async {
        let parameters = RequestParameters()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { _ in
                // `windows` and `isKeyWindow` are @MainActor-isolated, so the
                // key-path syntax doesn't compile inside this nonisolated
                // ObjC callback even though the enclosing function is
                // @MainActor. Hop onto the main actor explicitly.
                Task { @MainActor in
                    guard
                        let rootVC = UIApplication.shared.connectedScenes
                            .compactMap({ $0 as? UIWindowScene })
                            .flatMap({ $0.windows })
                            .first(where: { $0.isKeyWindow })?
                            .rootViewController
                    else {
                        continuation.resume()
                        return
                    }

                    ConsentForm.loadAndPresentIfRequired(from: rootVC) { _ in
                        continuation.resume()
                    }
                }
            }
        }
    }
}
