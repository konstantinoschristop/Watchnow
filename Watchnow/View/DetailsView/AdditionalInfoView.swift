//
//  AdditionalInfoView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 31/8/22.
//

import SwiftUI

struct AdditionalInfoView: View {
    
    let details: ContentDetailsModel
    @State var isSheetPresented = false
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 20) {
            
            if let createdBy = details.getCreatedBy() {
                getView(title: "Created By", subtitle: createdBy)
            }
            
            if let runtime = details.getRuntime() {
                getView(title: "Runtime", subtitle: [runtime])
            }
            
            if let spokenLanguages = details.getLanguages() {
                getView(title: "Spoken Languages", subtitle: spokenLanguages)
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
            
            if let homepage = details.homepage {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Homepage")
                        .font(.system(size: 15, weight: .bold))
                    Button {
                        isSheetPresented.toggle()
                    } label: {
                        Text(homepage)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
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
                        .font(.system(size: 15, weight: .medium))
                    
                    if sub != subtitle.last {
                        Text(", ")
                    }
                }
            }
        }
    }
}
