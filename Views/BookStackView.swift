//
//  BookStackView.swift
//  JjingToDo
//

import SwiftUI
import UIKit

@inline(__always)
private func safeCGFloat(_ x: CGFloat, min minV: CGFloat = 0,
                         max maxV: CGFloat = .greatestFiniteMagnitude) -> CGFloat {
    guard x.isFinite else { return minV }
    if x.isNaN { return minV }
    return Swift.max(minV, Swift.min(x, maxV))
}

// MARK: - 표지 대표색 추출
enum CoverColorExtractor {
    private static let cache = NSCache<NSString, UIColor>()

    static func dominantColor(from urlString: String) async -> UIColor? {
        let key = urlString as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let url = URL(string: urlString),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let img = UIImage(data: data),
              let color = dominantColor(of: img) else { return nil }
        cache.setObject(color, forKey: key)
        return color
    }

    /// 24×24로 축소 후 양자화 히스토그램에서 최빈 색 선택 (흰/검/회색 계열 제외)
    static func dominantColor(of image: UIImage) -> UIColor? {
        guard let cg = image.cgImage else { return nil }
        let w = 24, h = 24
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &pixels, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        struct Bucket { var n = 0; var r = 0; var g = 0; var b = 0 }
        var buckets: [Int: Bucket] = [:]
        var all = Bucket()

        for i in stride(from: 0, to: pixels.count, by: 4) {
            let r = Int(pixels[i]), g = Int(pixels[i + 1]), b = Int(pixels[i + 2])
            all.n += 1; all.r += r; all.g += g; all.b += b

            let maxC = max(r, g, b), minC = min(r, g, b)
            if maxC > 235 && minC > 210 { continue }   // 흰색 계열
            if maxC < 40 { continue }                    // 검은색 계열
            if maxC - minC < 16 { continue }             // 회색 계열

            let key = ((r >> 5) << 6) | ((g >> 5) << 3) | (b >> 5)
            var e = buckets[key, default: Bucket()]
            e.n += 1; e.r += r; e.g += g; e.b += b
            buckets[key] = e
        }

        let winner = buckets.values.max(by: { $0.n < $1.n })
        let pick = (winner?.n ?? 0) >= 8 ? winner! : all   // 유채색이 너무 적으면 전체 평균
        guard pick.n > 0 else { return nil }
        return UIColor(red: CGFloat(pick.r) / CGFloat(pick.n) / 255.0,
                       green: CGFloat(pick.g) / CGFloat(pick.n) / 255.0,
                       blue: CGFloat(pick.b) / CGFloat(pick.n) / 255.0,
                       alpha: 1.0)
    }

    static func luminance(_ c: UIColor) -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.299 * r + 0.587 * g + 0.114 * b
    }
}

struct BookStackView: View {
    let book: Book
    var tone: CGFloat = 1.0

    @AppStorage("spineUsesCoverColor") private var useCoverColor = true
    @State private var coverUIColor: UIColor? = nil

    var body: some View {
        let isKo = book.isKorean
        let pagesSafe = max(1, Int(book.pages))
        let hRaw = spineHeight(pages: Int32(pagesSafe), isKorean: isKo, effort: 1.0)
        let minH = SpineConfig.minH
        let maxH = SpineConfig.maxH ?? .greatestFiniteMagnitude
        let h = safeCGFloat(hRaw, min: minH, max: maxH)

        let coverActive = useCoverColor && coverUIColor != nil
        let baseTop: Color = coverActive ? Color(coverUIColor!) : (isKo ? Palette.koTop : Palette.enTop)
        let center = baseTop.adjusted(brightness: tone, saturation: 1.0)
        let edge   = baseTop.adjusted(brightness: tone * 0.94, saturation: 1.0)

        // 어두운 표지 색 위에서는 흰 글씨
        let darkSpine = coverActive && CoverColorExtractor.luminance(coverUIColor!) < 0.5
        let textColor: Color = darkSpine ? .white.opacity(0.92) : Palette.textDark

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
                .foregroundStyle(textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 12)
                .shadow(color: darkSpine ? .black.opacity(0.2) : .white.opacity(0.12), radius: 0, x: 0, y: 1)
        }
        .frame(height: h, alignment: .center)
        .clipped()
        .contentShape(Rectangle())
        .shadow(color: .black.opacity(0.07), radius: 3, x: 0, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.black.opacity(0.05), lineWidth: 0.8))
        .task(id: "\(book.coverURL ?? "")|\(useCoverColor)") {
            guard useCoverColor, let s = book.coverURL, !s.isEmpty else { return }
            coverUIColor = await CoverColorExtractor.dominantColor(from: s)
        }
    }
}
