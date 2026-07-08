//
//  BookStackView.swift
//  JjingToDo
//

import SwiftUI
import UIKit
import CryptoKit

@inline(__always)
private func safeCGFloat(_ x: CGFloat, min minV: CGFloat = 0,
                         max maxV: CGFloat = .greatestFiniteMagnitude) -> CGFloat {
    guard x.isFinite else { return minV }
    if x.isNaN { return minV }
    return Swift.max(minV, Swift.min(x, maxV))
}

// MARK: - 표지 이미지 저장소 (메모리 + 디스크 캐시)
enum CoverImageStore {
    private static let memCache = NSCache<NSString, UIImage>()

    private static let dir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let d = base.appendingPathComponent("BookCovers", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    private static func fileURL(for urlString: String) -> URL {
        let digest = SHA256.hash(data: Data(urlString.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return dir.appendingPathComponent(name + ".img")
    }

    /// 메모리 → 디스크 → 네트워크 순으로 표지 이미지 로드. 다운로드 시 디스크에 저장.
    static func image(for urlString: String) async -> UIImage? {
        let key = urlString as NSString
        if let hit = memCache.object(forKey: key) { return hit }

        let file = fileURL(for: urlString)
        if let img = UIImage(contentsOfFile: file.path) {
            memCache.setObject(img, forKey: key)
            return img
        }

        guard let url = URL(string: urlString),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let img = UIImage(data: data) else { return nil }

        try? data.write(to: file, options: .atomic)
        memCache.setObject(img, forKey: key)
        return img
    }
}

// MARK: - 표지 대표색 추출 (글자색 판단용)
enum CoverColorExtractor {
    private static let cache = NSCache<NSString, UIColor>()

    static func dominantColor(from urlString: String) async -> UIColor? {
        let key = urlString as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let img = await CoverImageStore.image(for: urlString),
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

    @AppStorage("spineUsesCoverColor") private var useCoverTexture = true
    @State private var coverImage: UIImage? = nil
    @State private var coverDominant: UIColor? = nil

    var body: some View {
        let isKo = book.isKorean
        let pagesSafe = max(1, Int(book.pages))
        let hRaw = spineHeight(pages: Int32(pagesSafe), isKorean: isKo, effort: 1.0)
        let minH = SpineConfig.minH
        let maxH = SpineConfig.maxH ?? .greatestFiniteMagnitude
        let h = safeCGFloat(hRaw, min: minH, max: maxH)

        let textureActive = useCoverTexture && coverImage != nil

        let baseTop    = isKo ? Palette.koTop    : Palette.enTop
        let center = baseTop.adjusted(brightness: tone, saturation: 1.0)
        let edge   = baseTop.adjusted(brightness: tone * 0.94, saturation: 1.0)

        // 어두운 표지 위에서는 흰 글씨
        let darkSpine = textureActive && coverDominant.map { CoverColorExtractor.luminance($0) < 0.5 } ?? false
        let textColor: Color = darkSpine ? .white.opacity(0.95) : Palette.textDark

        let baseFont: CGFloat = 13
        let minFont: CGFloat = 13
        let safeInset: CGFloat = 6
        let fontCandidate = min(baseFont, h - safeInset)
        let fontSize = safeCGFloat(fontCandidate, min: minFont, max: baseFont)

        ZStack {
            // 책등 바탕: 표지 텍스처 또는 기존 테마 그라데이션
            Group {
                if textureActive, let img = coverImage {
                    Color.clear
                        .overlay(
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .blur(radius: 5, opaque: true)
                                .saturation(1.15)
                        )
                        .overlay(
                            // 텍스처 위 은은한 정돈용 스크림 (제목 가독성)
                            LinearGradient(
                                colors: [
                                    .black.opacity(darkSpine ? 0.10 : 0.0),
                                    .white.opacity(darkSpine ? 0.0 : 0.10)
                                ],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                } else {
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
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Palette.stroke, lineWidth: 1))
            .overlay(
                // 책등 특유의 상하 음영 (하이라이트 + 그림자)
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

            if !isKo && !textureActive {
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
                .shadow(color: darkSpine ? .black.opacity(0.35) : .white.opacity(0.25), radius: 1.5, x: 0, y: 1)
        }
        .frame(height: h, alignment: .center)
        .clipped()
        .contentShape(Rectangle())
        .shadow(color: .black.opacity(0.07), radius: 3, x: 0, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.black.opacity(0.05), lineWidth: 0.8))
        .task(id: "\(book.coverURL ?? "")|\(useCoverTexture)") {
            guard useCoverTexture, let s = book.coverURL, !s.isEmpty else { return }
            coverImage = await CoverImageStore.image(for: s)
            coverDominant = await CoverColorExtractor.dominantColor(from: s)
        }
    }
}
