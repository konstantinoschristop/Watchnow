//
//  ContentDetailsView.swift
//  Watchnow
//
//  Created by k.christopoulos on 5/8/21.
//

import SwiftUI
import Kingfisher

enum ScreenTypes: String {
    case movie
    case tv
}

struct ContentDetailsView: View {
    
    let result: Result
    let screenType: ScreenTypes
    @StateObject private var creditsVM: CreditsViewModel
    @Environment(\.presentationMode) var presentation
    @State var showDetails = false
    
    init(result: Result, screenType: ScreenTypes) {
        self.screenType = screenType
        self.result = result
        _creditsVM = StateObject(wrappedValue: CreditsViewModel.init(service: ServiceInvaction.init(), screenType: screenType, id: String(describing: result.id!)))
    }
    
    @ViewBuilder
    func Details() -> some View {
        VStack(alignment: .center) {
            ZStack {
                VStack {
                    
                    if let overview = result.overview {
                        Text(overview)
                    }
                    Spacer()
                        .frame(height: 20)
                    
                    HStack {
                        if let rating = result.vote_average {
                            Image(systemName: "star.fill")
                                .foregroundColor(.orange)
                            Text(String(format: "%.1f", rating) + "/10")
                        }
                        if let allRatings = result.vote_count {
                            Text("• " + String(allRatings) + " ratings")
                        }
                        if let releaseData = result.release_date?.dropLast(6) {
                            Text("• Release Date: " + releaseData)
                        }
                    }
                    .font(.custom("AvenirNext-Regular", size: 15))
                    .foregroundColor(.gray)
                }
            }
        }
        .padding(.init(top: 0, leading: 20, bottom: 0, trailing: 20))
    }
    
    var body: some View {
                    
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ImageView(result: result)
                }
                VStack {
                    Details()
                    CastView(cast: creditsVM.credits?.cast)
                }
                .padding(.top, 25)
                .padding(.bottom, 100)
            }

            //.ignoresSafeArea(.container, edges: .vertical)
//            .navigationBarItems(leading: Button(action : {
//                self.presentation.wrappedValue.dismiss()
//            }){
//                Image(systemName: "arrow.backward.circle.fill")
//                    .resizable()
//                    .frame(width: 25, height: 25)
//                    .foregroundColor(Color(.systemBackground))
//                   // .colorInvert()
//            })
        
        .task {
            await creditsVM.getCredits()
        }
    }
}

extension UINavigationController {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = nil
    }
}
