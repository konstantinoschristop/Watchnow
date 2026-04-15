//
//  ContentMainView.swift
//  Watchnow
//
//  Created by k.christopoulos on 28/9/25.
//

import SwiftUI

struct ContentMainView<VM: BaseContentViewModel>: View {
    @ObservedObject var viewModel: VM
    @Namespace private var namespace
    
    let sections: [ViewSections]
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            if let results = viewModel.featuredResult {
                MenuFeaturedView(results: results,
                                 overlayContent: { result in overlayContent(for: result) },
                                 screenType: sections.allSatisfy({ $0.screenType == .movie }) ? .movie : .tv,
                                 showNavBar: .constant(true))
            }
            LazyVStack(spacing: 6) {
                ForEach(sections, id: \.self) { section in
                    if let results = results(for: section, from: viewModel) {
                        if section.isTopView {
                            TopView(results: results,
                                    viewTitle: section.title,
                                    screenType: section.screenType,
                                    viewModel: viewModel,
                                    viewSection: section)
                        } else {
                            BottomView(results: results,
                                       viewTitle: section.title,
                                       screenType: section.screenType,
                                       viewModel: viewModel,
                                       viewSection: section)
                        }
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onLoad { Task { await viewModel.loadContent() } }
        .redacted(reason: viewModel.finishedLoadingContent ? [] : .placeholder)
        .toolbarTitleDisplayMode(.inlineLarge)
    }
    
    private func results(for section: ViewSections, from viewModel: BaseContentViewModel) -> [Result]? {
        switch section {
        case .trendingMovies, .trendingSeries: return viewModel.trending?.result.results
        case .popularMovies, .popularSeries: return viewModel.popular?.result.results
        case .upcomingMovies, .airingTodaySeries: return viewModel.special?.result.results
        case .latestMovies, .latestSeries: return viewModel.latest?.result.results
        }
    }
}

extension ContentMainView {

    @ViewBuilder
    func overlayContent(for content: Result) -> some View {
        ZStack {
            LinearGradient(colors: [.clear,
                                    .black.opacity(0.6)],
                           startPoint: .center,
                           endPoint: .bottom)
            
            ZStack(alignment: .bottom) {
                Rectangle()
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, maxHeight: 120)
                    .blur(radius: 20)
                    .opacity(0.5)
                
                VStack(alignment: .center, spacing: 3) {
                    Text("Spotlight")
                        .font(.custom("AvenirNext-Regular", size: 20))
                    
                    Text(content.getResultTitle())
                        .font(.custom("AvenirNext-Bold", size: 25))
                        .multilineTextAlignment(.center)
                    
                    HStack {
                        Text(content.getReleaseDate(addSeparator: false))
                        Text(" | ")
                        HStack(spacing: 5) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.orange)
                            Text(content.vote_average.map { String(format: "%.1f", $0) } ?? "-")
                        }
                    }
                    .font(.custom("AvenirNext-Regular", size: 18))
                }
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(.white)
                .shadow(color: .black, radius: 3)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding()
            }
            .padding(.bottom, 20)
        }
    }
}
