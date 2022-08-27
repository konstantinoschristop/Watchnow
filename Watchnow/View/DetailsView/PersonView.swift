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
    @Environment(\.presentationMode) var presentation
    @State var imageFinishedLoading = false
    
    init(personID: Int) {
        
        _personViewModel = StateObject(wrappedValue: PersonViewModel.init(service: ServiceInvaction(), personID: personID))
    }
    var body: some View {
        
        Group {
            if let person = personViewModel.person {
                ZStack(alignment: .top) {
                    self.constructDetailsView(person: person)
                    GeometryReader { geometry in
                        constructNavigationBar(person: person)
                            .frame(width: geometry.size.width,
                                   height: 50 + geometry.safeAreaInsets.top)
                            .ignoresSafeArea()
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(.systemGray6))
        .navigationBarHidden(true)
        .task {
            await personViewModel.getPersonDetails()
        }
    }
    
    fileprivate func constructNavigationBar(person: PersonModel) -> NavigationBar {
        return NavigationBar(leftButtonIcon: "arrow.backward.circle.fill",
                             leftButtonAction: {
            self.presentation.wrappedValue.dismiss()
        },
                             title: personViewModel.imageHeight < 150 ? person.name : "",
                             opacity: personViewModel.imageHeight < 150 ? 1 : 0)
    }
    
    func constructDetailsView(person: PersonModel) -> some View {
        
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Image
                self.createImageView(person: person)
            }
            VStack {
                // Details
                self.createPersonalInfoView(person: person)
                
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
    
    fileprivate func createCareerView(person: PersonModel) -> some View {
        return Group {
            // Career
            /// biography
            if let bio = person.biography {
                Text(bio)
            }
        }
        .padding()
    }
    
    fileprivate func createPersonalInfoView(person: PersonModel) -> some View {
        
        if let birthDay = person.birthday?.dropLast(6),
           let birthPlace = person.place_of_birth {
            
            if let deathDay = person.deathday?.dropLast(6) {
                return AnyView (
                    HStack {
                        Text(birthDay)
                        Divider()
                        Text(deathDay)
                        Divider()
                        Text(birthPlace)
                    }
                        .padding()
                )
            }
            
            return AnyView (
                HStack {
                    Text(birthDay)
                    Divider()
                    Text(birthPlace)
                }
                    .padding()
            )
        }
        
        return AnyView(Group {})
    }
    
    fileprivate func createImageView(person: PersonModel) -> some View {
        return GeometryReader { proxy  in
            let minY = proxy.frame(in: .named("SCROLL")).minY
            let size = proxy.size
            let height = size.height + minY
            
            if let name = person.name {
                Group {
                    if let imageURL = person.profile_path {
                        KFImage.url(URL(string: APIKeys().imageKey + imageURL))
                            .placeholder { ProgressView() }
                            .loadImmediately()
                            .loadDiskFileSynchronously()
                            .fromMemoryCacheOrRefresh()
                            .cacheOriginalImage()
                            .fade(duration: 0.25)
                            .onProgress { receivedSize, totalSize in }
                            .onSuccess { result in  self.imageFinishedLoading = true }
                            .onFailure { error in }
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size.width, height: height > 0 ? height : 0 , alignment: .top)
                    } else {
                        Image(systemName: "person.text.rectangle")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size.width, height: height > 0 ? height : 0 , alignment: .bottom)
                    }
                }
               // .navigationBarTitle(height < 130 && imageFinishedLoading ? name : "")
                .overlay {
                    ZStack(alignment: .bottom) {
                        LinearGradient(colors: [.clear,
                                                .black.opacity(0.6)],
                                       startPoint: .center,
                                       endPoint: .bottom)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(name)
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
                .ignoresSafeArea()
                .cornerRadius(1)
                .offset(y: -minY)
                .onChange(of: height) { newValue in
                    self.personViewModel.imageHeight = Float(newValue)
                }
            }
        }
        .frame(height: 400)
    }
}
