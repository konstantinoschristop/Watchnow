////
////  AdBannerView.swift
////  Watchnow
////
////  Created by Konstantinos Christopoulos on 25/6/23.
////
//
//import SwiftUI
//import GoogleMobileAds
//
//protocol BannerViewControllerWidthDelegate: AnyObject {
//  func bannerViewController(_ bannerViewController: BannerViewController, didUpdate width: CGFloat)
//}
//
//class BannerViewController: UIViewController {
//  weak var delegate: BannerViewControllerWidthDelegate?
//
//  override func viewDidAppear(_ animated: Bool) {
//    super.viewDidAppear(animated)
//
//    // Tell the delegate the initial ad width.
//    delegate?.bannerViewController(
//      self, didUpdate: view.frame.inset(by: view.safeAreaInsets).size.width)
//  }
//
//  override func viewWillTransition(
//    to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator
//  ) {
//    coordinator.animate { _ in
//      // do nothing
//    } completion: { _ in
//      // Notify the delegate of ad width changes.
//      self.delegate?.bannerViewController(
//        self, didUpdate: self.view.frame.inset(by: self.view.safeAreaInsets).size.width)
//    }
//  }
//}
//
//struct AdBannerView: UIViewControllerRepresentable {
//    
//    @State private var viewWidth: CGFloat = UIScreen.main.bounds.width
//    private let bannerView = GADBannerView()
//    private let adUnitID = "ca-app-pub-5275868523622377~8809630719"
//    
//    func makeUIViewController(context: Context) -> some UIViewController {
//        let bannerViewController = BannerViewController()
//        bannerView.adUnitID = adUnitID
//        bannerView.rootViewController = bannerViewController
//        bannerViewController.view.addSubview(bannerView)
//        return bannerViewController
//    }
//    
//    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
//        guard viewWidth != .zero else { return }
//        
//        // Request a banner ad with the updated viewWidth.
//        bannerView.adSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(viewWidth)
//        bannerView.load(GADRequest())
//    }
//}
