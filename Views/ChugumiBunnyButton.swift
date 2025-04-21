//
//  ChugumiBunnyButton.swift
//  JjingToDo
//
//  Created by Jeongah Seo on 4/21/25.
//

import SwiftUI

struct ChugumiBunnyButton: View {
    let imageName: String
    let label: String
    let type: String
    let onTap: (_ type: String) -> Void

    @State private var isAnimating = false

    var body: some View {
        Button {
            isAnimating = true
            onTap(type)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring()) {
                    isAnimating = false
                }
            }
        } label: {
            VStack(spacing: 8) {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)   //커졌다 작아짐
                    .offset(y: isAnimating ? -10 : 0)       //점프
                    .animation(.easeOut(duration: 0.2), value: isAnimating)
                    .rotationEffect(.degrees(isAnimating ? -10 : 0))    //살짝 좌우 흔들림

                Text(label)
                    //.font(.headline)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(type == "참기" ? Color(hex: "#bcc8ce") : Color(hex: "#e6bacf"))
                    //.shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                    .shadow(color: .white.opacity(0.8), radius: 1) // 밝은 아우라 느낌
            }
            .padding()
            //.background(Color(.systemGray6))
            //.cornerRadius(16)
        }
    }
}
