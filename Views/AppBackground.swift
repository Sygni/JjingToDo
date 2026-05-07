//
//  AppBackground.swift
//  JjingToDo
//

import SwiftUI

struct AppBackground: View {
    var imageName: String? = "StackBG"

    var body: some View {
        ZStack {
            if let name = imageName, UIImage(named: name) != nil {
                Image(name)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay(
                        ZStack {
                            Color.white.opacity(0.5)
                            RadialGradient(
                                colors: [.black.opacity(0.18), .clear],
                                center: .center, startRadius: 0, endRadius: 900
                            )
                            .blendMode(.multiply)
                        }
                        .ignoresSafeArea()
                    )
            } else {
                LinearGradient(
                    colors: [Color(hex: "#FFF7EE"), Color(hex: "#F5E7D6")],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        }
        .allowsHitTesting(false)
    }
}
