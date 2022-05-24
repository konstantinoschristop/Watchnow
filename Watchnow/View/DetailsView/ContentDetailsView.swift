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
    
    fileprivate func Details() -> some View {
        return VStack(alignment: .center) {
            ZStack {
                VStack {
                    HStack {
                        Text((result.title ?? result.name) ?? "")
                            .font(.custom("AvenirNext-Bold", size: 30))
                            .lineLimit(nil)
                        Spacer()
                        VStack {
                            Button(action: {
                                
                            }) {
                                Image(systemName: "plus.rectangle.on.rectangle")
                                    .imageScale(.large)
                            }
                            Spacer()
                                .frame(height: 10)
                            Text("Wathclist")
                                .font(.custom("AvenirNext-Bold", size: 12))
                        }
                    }
                    Spacer()
                        .frame(height: 10)
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
                            Text("• Released: " + releaseData)
                        }
                    }
                    .font(.custom("AvenirNext-Regular", size: 15))
                    .foregroundColor(.gray)
                }
            }
            Spacer()
                .frame(height: 20)
            
            if let overview = result.overview {
                Text(overview)
            }
        }
        .padding(.init(top: 0, leading: 20, bottom: 0, trailing: 20))
    }
    
    var body: some View {
        
        Group {
            ZStack {
                    ScrollView {
                        VStack {
                            ImageView(result: result)
                            ZStack {
                                Rectangle()
                                    .background(Color(.systemBackground))
                                    .colorInvert()
                                    .mask(LinearGradient(gradient: Gradient(colors: [Color.black, Color.clear]), startPoint: .center, endPoint: .top))
                                VStack {
                                    Details()
                                    CastView(cast: creditsVM.credits?.cast)
                                }
                                .padding(.top, -10)
                            }
                        }
                    }
                   // .navigationBarBackButtonHidden(true)
//                    .navigationBarItems(leading: Button(action : {
//                        self.presentation.wrappedValue.dismiss()
//                    }){
//                        Image(systemName: "arrow.backward.circle.fill")
//                            .resizable()
//                            .frame(width: 25, height: 25)
//                            .foregroundColor(Color(.systemGray6))
//                            .colorInvert()
//                    })
            }
        }
        .task {
            await creditsVM.getCredits()
        }
    }
}
