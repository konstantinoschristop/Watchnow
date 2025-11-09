//
//  ScrollableTabBar.swift
//  Watchnow
//
//  Created by k.christopoulos on 9/11/25.
//

import SwiftUI

struct ScrollableTabBar<IdentifierType: Hashable>: View {
    let items: [IdentifierType]
    @Binding var selectedItem: IdentifierType
    let titleForItem: (IdentifierType) -> String
    
    private let horizontalPadding: CGFloat = 20
    private let itemSpacing: CGFloat = 8
    private let scrollHeight: CGFloat = 40
    private let animationDuration: Double = 0.2

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: itemSpacing) {
                    Color.clear.frame(width: horizontalPadding)
                    
                    ForEach(items, id: \.self) { item in
                        Button {
                            withAnimation(.easeInOut(duration: animationDuration)) {
                                selectedItem = item
                                proxy.scrollTo(item, anchor: .center)
                            }
                        } label: {
                            Text(titleForItem(item))
                                .bold()
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(
                                    selectedItem == item
                                    ? Color(.systemGray5)
                                    : Color.clear
                                )
                                .cornerRadius(10)
                                .opacity(selectedItem == item ? 1.0 : 0.5)
                        }
                        .buttonStyle(.plain)
                        .id(item)
                    }

                    Color.clear.frame(width: horizontalPadding)
                }
                .frame(height: scrollHeight)
            }
        }
    }
}
