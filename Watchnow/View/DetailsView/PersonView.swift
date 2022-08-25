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
                self.constructDetailsView(person: person)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(.systemGray6))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Button(action : {
            self.presentation.wrappedValue.dismiss()
        }){
            Image(systemName: "arrow.backward.circle.fill")
                .resizable()
                .frame(width: 25, height: 25)
                .foregroundColor(.white)
                .shadow(color: .black, radius: 3)
        })
        .task {
            await personViewModel.getPersonDetails()
        }
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
                        Image(systemName: "person.fill.questionmark")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size.width, height: height > 0 ? height : 0 , alignment: .bottom)
                    }
                }
                .navigationBarTitle(height < 130 && imageFinishedLoading ? name : "")
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
            }
        }
        .frame(height: 350)
    }
}
