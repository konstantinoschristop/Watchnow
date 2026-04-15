//
//  StretchingActionScrollView.swift
//  Watchnow
//
//  Created by k.christopoulos on 21/9/25.
//

import SwiftUI

struct StretchingActionScrollView<Content: View>: UIViewRepresentable {

    var threshold: CGFloat
    var onTriggered: () -> Void
    var onThresholdReached: ((Bool) -> Void)?
    var content: Content

    init(threshold: CGFloat = 70,
         onTriggered: @escaping () -> Void,
         onThresholdReached: ((Bool) -> Void)?,
         @ViewBuilder content: () -> Content) {

        self.threshold = threshold
        self.onTriggered = onTriggered
        self.onThresholdReached = onThresholdReached
        self.content = content()
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceHorizontal = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .clear
        scrollView.delegate = context.coordinator

        // Create the hosting controller once and keep it for the view's lifetime.
        let hosting = UIHostingController(rootView: content)
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        context.coordinator.hostingController = hosting

        scrollView.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hosting.view.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // Only update the SwiftUI content — no teardown/rebuild.
        context.coordinator.hostingController?.rootView = content
    }

    class Coordinator: NSObject, UIScrollViewDelegate {

        var parent: StretchingActionScrollView
        var hostingController: UIHostingController<Content>?
        var didTrigger = false
        var didTriggerHaptic = false
        var overscroll: CGFloat = 0

        init(parent: StretchingActionScrollView) { self.parent = parent }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // UIScrollViewDelegate is always called on the main thread — no dispatch needed.
            let maxOffset = max(0, scrollView.contentSize.width - scrollView.bounds.width)
            let overs = max(0, scrollView.contentOffset.x - maxOffset)
            self.overscroll = overs

            if overs > parent.threshold, !didTriggerHaptic {
                UIImpactFeedbackGenerator().impactOccurred()
                didTriggerHaptic = true
                parent.onThresholdReached?(true)
            } else if overs < parent.threshold / 1.5 {
                if didTriggerHaptic {
                    didTriggerHaptic = false
                    parent.onThresholdReached?(false)
                }
            }
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if overscroll >= parent.threshold && !didTrigger {
                didTrigger = true
                parent.onTriggered()
            } else if overscroll <= 0 {
                didTrigger = false
                didTriggerHaptic = false
            }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            if overscroll <= 0 {
                didTrigger = false
                didTriggerHaptic = false
            }
        }
    }
}
