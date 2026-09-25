//
//  PosterImage.swift
//  Watchnow
//
//  Created by k.christopoulos on 20/9/25.
//

import SwiftUI
import Kingfisher

struct PosterImage: View {
    var url: URL?
    var width: CGFloat = 250
    var height: CGFloat = 450
    var cornerRadius: CGFloat = 15
    var shadowRadius: CGFloat = 5

    var body: some View {
        KFImage.url(url)
            .downsampling(size: CGSize(width: width, height: height))
            .loadImmediately()
            .fromMemoryCacheOrRefresh()
            .cacheOriginalImage()
            .backgroundDecode()
            .fade(duration: 0.25)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(shape)
            .background { shadowLayer }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    /// The drop shadow, cast by an opaque shape *behind* the poster instead
    /// of by the poster itself.
    ///
    /// `.shadow` applied after a clip has no path to work from, so Core
    /// Animation derives it from the composited alpha — an offscreen
    /// rasterisation pass every frame the card moves. The home feed keeps
    /// every card of every row alive (the rows are plain `HStack`s), so that
    /// was being paid twenty times a row on every scroll. Shadowing a filled
    /// shape is a simple path the compositor can cache, and the poster is
    /// opaque and fills the shape, so it looks the same.
    @ViewBuilder
    private var shadowLayer: some View {
        if shadowRadius > 0 {
            shape
                .fill(Color.black)
                .shadow(color: .black, radius: shadowRadius)
        }
    }
}
