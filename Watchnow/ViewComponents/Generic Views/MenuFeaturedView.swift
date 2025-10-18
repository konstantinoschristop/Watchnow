//
//  MenuFeaturedView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 13/6/23.
//

import SwiftUI
import Kingfisher

struct MenuFeaturedView<Content: View>: View {
    var results: [Result]
    var overlayContent: (Result) -> Content
    let screenType: ScreenTypes
    @Binding var showNavBar: Bool
    @State var currentTab: Int = 0 {
        didSet {
            stopTimer()
            startTimer()
        }
    }
    @State private var isDragging: Bool = false
    @State var timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    @State private var selectedResult: Result?
    
    var body: some View {
        
        TabView(selection: $currentTab,
                content: {
            ForEach(results.indices, id: \.self) { index in
                getImage(for: index)
                    .overlay {
                        overlayContent(results[index])
                    }
            }
        })
        .stretchy()
        .frame(height: (UIScreen.main.bounds.size.height) - (UIScreen.main.bounds.size.height / 3))
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .onReceive(timer) { _ in
            guard !isDragging else { return }
            withAnimation {
                currentTab = (currentTab + 1) % results.count
            }
        }
        .onTapGesture {
            selectedResult = results[currentTab]
        }
        .navigationDestination(item: $selectedResult) { result in
            let model = ContentDetailsModel(screenType: screenType, result: result)
            let vm = ContentDetailsViewModel(model: model)
            ContentDetailsView(detailsViewModel: vm)
        }
    }

    func getImage(for index: Int) -> some View {
        
        KFImage.url(results[index].getResultPosterURL())
            .placeholder {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .loadImmediately()
            .loadDiskFileSynchronously()
            .fromMemoryCacheOrRefresh()
            .cacheOriginalImage()
            .fade(duration: 0.25)
            .resizable()
            .tag(index)
    }
    
    private func stopTimer() {
        timer.upstream.connect().cancel()
    }

    private func startTimer() {
        timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    }
}

