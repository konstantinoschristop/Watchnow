//
//  NavigationBar.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 25/8/22.
//

import SwiftUI

public struct BlurView: UIViewRepresentable {
    
    public func makeUIView(context: UIViewRepresentableContext<BlurView>) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(blurView, at: 0)

        NSLayoutConstraint.activate([
            blurView.heightAnchor.constraint(equalTo: view.heightAnchor),
            blurView.widthAnchor.constraint(equalTo: view.widthAnchor),
            blurView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            blurView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])

        return view
    }

    public func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<BlurView>) {
        guard let effectView = uiView.subviews.first as? UIVisualEffectView else { return }
        let blurEffect = UIBlurEffect(style: context.environment.colorScheme == .dark ? .dark : .light)
        effectView.effect = blurEffect
    }
}

struct NavigationBar: View {
    
    var leftButtonIcon: String?
    var leftButtonAction: (() -> Void)?
    var rightButtonIcon: String?
    var rightButtonAction: (() -> Void)?
    var secondRightButtonIcon: String?
    var secondRightButtonAction: (() -> Void)?
    var title: String?
    var opacity: Double?
    
    var body: some View {
        
        ZStack(alignment: .bottom) {
            BlurView()
                .opacity(opacity ?? 0)
                .animation(.spring())
            HStack(alignment: .center) {
                if let leftButtonIcon = leftButtonIcon,
                   let leftButtonAction = leftButtonAction {
                    Button {
                        leftButtonAction()
                    } label: {
                        Image(systemName: leftButtonIcon)
                            .resizable()
                            .frame(width: 25, height: 25)
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 3)
                    }
                    Spacer()
                }
                if let title = title {
                    Text(title)
                        .font(.system(size: 17))
                        .bold()
                        .lineLimit(1)
                    Spacer()
                }
                if let rightButtonIcon = rightButtonIcon,
                   let rightButtonAction = rightButtonAction {
                    
                    HStack {
                        Button {
                            rightButtonAction()
                        } label: {
                            Image(systemName: rightButtonIcon)
                                .resizable()
                                .frame(width: 25, height: 25)
                                .foregroundColor(.white)
                                .shadow(color: .black, radius: 3)
                        }
                        
                        if let secondRightButtonIcon = secondRightButtonIcon,
                           let secondRightButtonAction = secondRightButtonAction {
                            
                            Button {
                                secondRightButtonAction()
                            } label: {
                                Image(systemName: secondRightButtonIcon)
                                    .resizable()
                                    .frame(width: 25, height: 25)
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 3)
                            }
                        }
                    }
                }
            }
            .padding(.all, 10)
        }
    }
}
