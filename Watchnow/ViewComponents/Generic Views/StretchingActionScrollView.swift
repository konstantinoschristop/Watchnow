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

    init(threshold: CGFloat = 100,
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
        
        setupHostingView(scrollView, context: context)
        
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        setupHostingView(uiView, context: context)
    }
    
    private func setupHostingView(_ uiView: UIScrollView, context: Context) {
        // 🔥 remove any old hosted views first
        uiView.subviews.forEach { $0.removeFromSuperview() }

        // create fresh hosting controller
        let hosting = UIHostingController(rootView: content)
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false

        // keep reference
        context.coordinator.hostingController = hosting

        // add hosted SwiftUI view
        uiView.addSubview(hosting.view)

        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: uiView.contentLayoutGuide.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: uiView.contentLayoutGuide.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: uiView.contentLayoutGuide.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: uiView.contentLayoutGuide.bottomAnchor),
            hosting.view.heightAnchor.constraint(equalTo: uiView.frameLayoutGuide.heightAnchor)
        ])
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        
        var parent: StretchingActionScrollView
        weak var hostingController: UIHostingController<Content>?
        var didTrigger = false
        var didTriggerHaptic: Bool = false {
            didSet {
                parent.onThresholdReached?(didTriggerHaptic)
            }
        }
        var overscroll : CGFloat = 0
        
        init(parent: StretchingActionScrollView) { self.parent = parent }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let maxOffset = max(0, scrollView.contentSize.width - scrollView.bounds.width)
            let overs = max(0, scrollView.contentOffset.x - maxOffset)
            self.overscroll = overs
            
            DispatchQueue.main.async {
                
                if overs > self.parent.threshold,
                   !self.didTriggerHaptic {
                    UIImpactFeedbackGenerator().impactOccurred()
                    self.didTriggerHaptic = true
                    self.parent.onThresholdReached?(true)
                } else if overs < self.parent.threshold / 1.5 {
                    self.didTriggerHaptic = false
                }
            }
        }
        
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            // only trigger after release if overscroll exceeded threshold
            if overscroll >= parent.threshold && !didTrigger {
                didTrigger = true
                parent.onTriggered()
            } else if overscroll <= 0 {
                didTrigger = false
                didTriggerHaptic = false
            }
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            // reset if user scrolls back
            if overscroll <= 0 {
                didTrigger = false
                didTriggerHaptic = false
            }
        }
    }
}
