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
    var onProgress: ((CGFloat) -> Void)?
    var content: Content

    init(threshold: CGFloat = 70,
         onTriggered: @escaping () -> Void,
         onThresholdReached: ((Bool) -> Void)?,
         onProgress: ((CGFloat) -> Void)? = nil,
         @ViewBuilder content: () -> Content) {

        self.threshold = threshold
        self.onTriggered = onTriggered
        self.onThresholdReached = onThresholdReached
        self.onProgress = onProgress
        self.content = content()
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceHorizontal = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .clear
        scrollView.clipsToBounds = false
        scrollView.delegate = context.coordinator
        context.coordinator.scrollView = scrollView

        let hosting = UIHostingController(rootView: content)
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        // iOS 16+: auto-invalidate intrinsic size when rootView changes so the
        // scroll view's contentSize grows when new items are appended.
        if #available(iOS 16.0, *) {
            hosting.sizingOptions = .intrinsicContentSize
        }
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
        // While the user is dragging or the view is decelerating/bouncing,
        // mutating rootView triggers a hosting-controller relayout that
        // destabilizes the UIScrollView (stuck scroll, content jumps).
        // Buffer the latest content and apply it once motion settles.
        if uiView.isDragging || uiView.isDecelerating {
            context.coordinator.pendingContent = content
        } else {
            context.coordinator.applyContent(content)
        }
    }

    class Coordinator: NSObject, UIScrollViewDelegate {

        var parent: StretchingActionScrollView
        var hostingController: UIHostingController<Content>?
        weak var scrollView: UIScrollView?
        var pendingContent: Content?

        var didTrigger = false
        var didTriggerHaptic = false
        var overscroll: CGFloat = 0

        init(parent: StretchingActionScrollView) { self.parent = parent }

        func applyContent(_ newContent: Content) {
            hostingController?.rootView = newContent
            // Force the hosting view to recompute its size so the scroll
            // view's contentSize grows when new items have been appended.
            hostingController?.view.invalidateIntrinsicContentSize()
            hostingController?.view.setNeedsLayout()
            pendingContent = nil
        }

        private func flushPendingContentIfIdle() {
            guard let pending = pendingContent,
                  let sv = scrollView,
                  !sv.isDragging, !sv.isDecelerating else { return }
            applyContent(pending)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let maxOffset = max(0, scrollView.contentSize.width - scrollView.bounds.width)
            let overs = max(0, scrollView.contentOffset.x - maxOffset)
            self.overscroll = overs

            let progress = min(overs / parent.threshold, 1.0)
            parent.onProgress?(progress)

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
            // If the user released without decelerating, apply any buffered content.
            if !decelerate { flushPendingContentIfIdle() }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            if overscroll <= 0 {
                didTrigger = false
                didTriggerHaptic = false
            }
            flushPendingContentIfIdle()
        }

        func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
            flushPendingContentIfIdle()
        }
    }
}
