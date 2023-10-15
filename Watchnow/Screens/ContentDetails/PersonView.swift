//
//  PersonView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 16/8/22.
//

import SwiftUI
import Kingfisher

struct PersonView: View {
    
    @StateObject var personViewModel: PersonViewModel
    @State var showNavBar: Bool = false
    @Environment(\.presentationMode) var presentation
    
    var body: some View {
        
        ScrollView(.vertical, showsIndicators: false) {
            if let person = personViewModel.person {
                
                VStack(spacing: 0) {
                    // Image
                    MenuFeaturedView(imageURL: person.getResultPosterURL(),
                                     overlayContent: overlayContent(for: person),
                                     showNavBar: $showNavBar)
                }
                VStack {
                    // Details
                    self.createPersonalInfoView(person: person)
                        .padding()
                    
                    HStack {
                        Text("Career")
                            .font(.system(size: 20, weight: .bold))
                        Spacer()
                    }
                    .padding(.top, 10)
                    .padding(.leading, 10)
                    self.createCareerView(person: person)
                }
            }
        }
        .overlay(alignment: .topLeading, content: {
            if !showNavBar {
                navBarLeadingView
                    .padding()
            }
        })
        .background(Color(.systemGray6))
        .navigationTitle(personViewModel.person?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(!showNavBar)
        .navigationBarBackButtonHidden()
        .navigationBarItems(leading: navBarLeadingView)
        .task {
            await personViewModel.getPersonDetails()
        }
    }
    
    fileprivate func createCareerView(person: PersonResponse) -> some View {
        return Group {
            // Career
            /// biography
            if let bio = person.biography {
                Text(bio)
            }
        }
        .padding()
    }
    
    @ViewBuilder
    fileprivate func createPersonalInfoView(person: PersonResponse) -> some View {
        
        if let birthDay = person.birthday?.dropLast(6),
           let birthPlace = person.place_of_birth {
            
            if let deathDay = person.deathday?.dropLast(6) {
                HStack {
                    Text(birthDay)
                    Divider()
                    Text(deathDay)
                    Divider()
                    Text(birthPlace)
                }
            }
            
            HStack {
                Text(birthDay)
                Divider()
                Text(birthPlace)
            }
        }
    }
    
    var navBarLeadingView: some View {
        
        getNavBarButton(imageName: "arrow.backward.circle.fill") {
            self.presentation.wrappedValue.dismiss()
        }
    }

    private func getNavBarButton(imageName: String,
                                 action: @escaping () -> Void) -> some View{
        
        Button(action: action,
               label: {
            Image(systemName: imageName)
                .resizable()
                .frame(width: 25, height: 25)
                .foregroundColor(.white)
                .shadow(color: .black, radius: 3)
        })
    }
    
    @ViewBuilder
    func overlayContent(for content: PersonResponse) -> some View {
            ZStack(alignment: .bottom) {
                LinearGradient(colors: [.clear,
                                        .black.opacity(0.6)],
                               startPoint: .center,
                               endPoint: .bottom)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(content.name ?? "")
                            .font(.custom("AvenirNext-Bold", size: 25))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .shadow(color: .black, radius: 3)
                }
                .padding(.horizontal)
                .padding(.bottom, 15)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
    }
}
