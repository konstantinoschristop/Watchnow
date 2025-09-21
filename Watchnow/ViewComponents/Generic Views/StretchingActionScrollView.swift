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
    var content: Content

    init(threshold: CGFloat = 110,
         onTriggered: @escaping () -> Void,
         @ViewBuilder content: () -> Content) {
        
        self.threshold = threshold
        self.onTriggered = onTriggered
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
        
        let hosting = UIHostingController(rootView: content)
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        
        context.coordinator.hostingController = hosting
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
        private var alreadyTriggered = false

        init(parent: StretchingActionScrollView) {
            self.parent = parent
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let maxOffset = max(0, scrollView.contentSize.width - scrollView.bounds.width)
            let overs = max(0, scrollView.contentOffset.x - maxOffset)

            DispatchQueue.main.async {

                if overs > self.parent.threshold && !self.alreadyTriggered {
        
                    self.alreadyTriggered = true
                    self.parent.onTriggered()
                }

                if overs == 0 {
                    self.alreadyTriggered = false
                }
            }
        }
    }
}
