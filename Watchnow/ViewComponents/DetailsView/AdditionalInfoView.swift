//
//  AdditionalInfoView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 31/8/22.
//

import SwiftUI

struct AdditionalInfoView: View {
    
    let details: ResultDetailsReponse
    @State var isSheetPresented = false
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 20) {
            
            if let createdBy = details.getCreatedBy(),
               createdBy.isEmpty == false {
                
                switch createdBy.count {
                case 1:
                    getView(title: "Created By", subtitle: createdBy)
                default:
                    getBulletListView(title: "Created By", bullets: createdBy)
                }
            }
            
            if let dateString = details.getDate() {
                getView(title: "Release Date", subtitle: [dateString])
            }
            
            if let runtime = details.getRuntime() {
                getView(title: "Runtime", subtitle: [runtime])
            }
            
            if let spokenLanguages = details.getLanguages(),
               spokenLanguages.isEmpty == false {
                
                switch spokenLanguages.count {
                case 1:
                    getView(title: "Spoken Languages", subtitle: spokenLanguages)
                default:
                    getBulletListView(title: "Spoken Languages", bullets: spokenLanguages)
                }
            }
            
            if let budget = details.getBudget() {
                getView(title: "Budget", subtitle: [budget])
            }
            
            if let revenue = details.getRevenue() {
                getView(title: "Revenue", subtitle: [revenue])
            }
            
            if let tagline = details.getTagline() {
                getView(title: "Tagline", subtitle: [tagline])
            }
            
            if let status = details.status {
                getView(title: "Status", subtitle: [status])
            }
            
            if let homepage = details.homepage,
               homepage.isEmpty == false {
                getLinkView(title: "Homepage", homepage: homepage)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $isSheetPresented) {
            WebView(videoURL: URL(string: details.homepage ?? ""))
                .ignoresSafeArea()
        }
    }
    
    func getView(title: String,
                 subtitle: [String]) -> some View {
        
        return VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
            HStack(spacing: 0) {
                ForEach(subtitle, id: \.self) { sub in
                    Text(sub)
                        .font(.system(size: 15, weight: .light))
                        .multilineTextAlignment(.leading)
                    if sub != subtitle.last {
                        Text(", ")
                    }
                }
            }
        }
    }
    
    func getLinkView(title: String,
                     homepage: String) -> some View {
        
        return VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
            Button {
                isSheetPresented.toggle()
            } label: {
                Text(homepage)
                    .font(.system(size: 15, weight: .light))
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.leading)
            }
        }
    }
    
    func getBulletListView(title: String,
                           bullets: [String]) -> some View {
        
        return VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
            VStack(alignment: .leading, spacing: 0) {
                ForEach(bullets, id: \.self) { bullet in
                    Text(" • " + bullet)
                        .font(.system(size: 15, weight: .light))
                        .multilineTextAlignment(.leading)
                }
            }
        }
    }
}
