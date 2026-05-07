//
//  BookStackView.swift
//  JjingToDo
//

import SwiftUI

@inline(__always)
private func safeCGFloat(_ x: CGFloat, min minV: CGFloat = 0,
                         max maxV: CGFloat = .greatestFiniteMagnitude) -> CGFloat {
    guard x.isFinite else { return minV }
    if x.isNaN { return minV }
    return Swift.max(minV, Swift.min(x, maxV))
}

struct BookStackView: View {
    let book: Book
    var tone: CGFloat = 1.0

    var body: some View {
        let isKo = book.isKorean
        let pagesSafe = max(1, Int(book.pages))
        let hRaw = spineHeight(pages: Int32(pagesSafe), isKorean: isKo, effort: 1.0)
        let minH = SpineConfig.minH
        let maxH = SpineConfig.maxH ?? .greatestFiniteMagnitude
        let h = safeCGFloat(hRaw, min: minH, max: maxH)

        let baseTop    = isKo ? Palette.koTop    : Palette.enTop
        let baseBottom = isKo ? Palette.koBottom : Palette.enBottom
        let center = baseTop.adjusted(brightness: tone, saturation: 1.0)
        let edge   = baseTop.adjusted(brightness: tone * 0.94, saturation: 1.0)

        let baseFont: CGFloat = 13
        let minFont: CGFloat = 13
        let safeInset: CGFloat = 6
        let fontCandidate = min(baseFont, h - safeInset)
        let fontSize = safeCGFloat(fontCandidate, min: minFont, max: baseFont)

        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: edge,   location: 0.0),
                        .init(color: center, location: 0.38),
                        .init(color: center, location: 0.62),
                        .init(color: edge,   location: 1.0)
                    ]),
                    startPoint: .top, endPoint: .bottom
                ))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Palette.stroke, lineWidth: 1))
                .overlay(
                    VStack(spacing: 0) {
                        LinearGradient(colors: [Color.white.opacity(0.24), .clear], startPoint: .top, endPoint: .bottom).frame(height: 6)
                        Spacer(minLength: 0)
                        LinearGradient(colors: [.black.opacity(0.12), .clear], startPoint: .bottom, endPoint: .top).frame(height: 6)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [.white.opacity(h > 24 ? 0.08 : 0.0), .clear], startPoint: .top, endPoint: .bottom),
                            lineWidth: 1.0
                        )
                )

            if !isKo {
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Palette.enAccent.opacity(0.72)).frame(width: 4)
                    Spacer()
                }
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            Text(book.title ?? "")
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(Palette.textDark)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 12)
                .shadow(color: .white.opacity(0.12), radius: 0, x: 0, y: 1)
        }
        .frame(height: h, alignment: .center)
        .clipped()
        .contentShape(Rectangle())
        .shadow(color: .black.opacity(0.07), radius: 3, x: 0, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.black.opacity(0.05), lineWidth: 0.8))
    }
}
