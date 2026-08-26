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

// MARK: - 이미지 회전
private extension UIImage {
    /// 왼쪽(반시계)으로 90도 회전 — 눕혀 쌓은 책 방향에 맞춤
    func rotated90CCW() -> UIImage {
        let newSize = CGSize(width: size.height, height: size.width)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { ctx in
            let c = ctx.cgContext
            c.translateBy(x: 0, y: newSize.height)
            c.rotate(by: -.pi / 2)
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - 표지 이미지 저장소 (메모리 + 디스크 캐시)
enum CoverImageStore {
    private static let memCache = NSCache<NSString, UIImage>()
    private static let rotatedCache = NSCache<NSString, UIImage>()

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

    /// 책등 텍스처용 — 왼쪽으로 90도 회전된 표지 (회전 결과도 메모리 캐시)
    static func spineImage(for urlString: String) async -> UIImage? {
        let key = ("rot|" + urlString) as NSString
        if let hit = rotatedCache.object(forKey: key) { return hit }
        guard let img = await image(for: urlString) else { return nil }
        let rotated = img.rotated90CCW()
        rotatedCache.setObject(rotated, forKey: key)
        return rotated
    }

    // MARK: 교보문고 실제 책등 이미지
    // addt/{isbn13}_0N.jpg 후보들 중 "흰 배경 + 좁고 긴 세로 띠" 이미지를 판별해 띠만 크롭

    private static func spineFile(isbn: String) -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BookCovers/spine_\(isbn).png")
    }
    private static func spineMissMarker(isbn: String) -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BookCovers/spine_\(isbn).none")
    }

    /// 교보 실제 책등 원본 (세로 방향, 크롭된 상태). 없으면 nil + 재시도 안 함 마커.
    static func kyoboSpineRaw(isbn: String) async -> UIImage? {
        let key = ("kspineraw|" + isbn) as NSString
        if let hit = memCache.object(forKey: key) { return hit }

        let file = spineFile(isbn: isbn)
        if let saved = UIImage(contentsOfFile: file.path) {
            memCache.setObject(saved, forKey: key)
            return saved
        }
        if FileManager.default.fileExists(atPath: spineMissMarker(isbn: isbn).path) { return nil }

        for n in 1...4 {
            let urlStr = "https://contents.kyobobook.co.kr/sih/fit-in/720x0/pdt/addt/\(isbn)_0\(n).jpg"
            guard let url = URL(string: urlStr),
                  let (data, resp) = try? await URLSession.shared.data(from: url),
                  (resp as? HTTPURLResponse)?.statusCode == 200,
                  let img = UIImage(data: data) else { continue }
            if let spine = Self.cropSpineStrip(img) {
                if let png = spine.pngData() { try? png.write(to: file, options: .atomic) }
                memCache.setObject(spine, forKey: key)
                return spine
            }
        }
        try? Data().write(to: spineMissMarker(isbn: isbn))
        return nil
    }

    /// 교보 실제 책등 (왼쪽 90도 회전 완료 상태로 반환)
    static func kyoboSpine(isbn: String) async -> UIImage? {
        let key = ("kspine|" + isbn) as NSString
        if let hit = rotatedCache.object(forKey: key) { return hit }
        guard let raw = await kyoboSpineRaw(isbn: isbn) else { return nil }
        let rotated = raw.rotated90CCW()
        rotatedCache.setObject(rotated, forKey: key)
        return rotated
    }

    /// 책등 캐시 삭제 (재조회 유도 — 잘못 매칭됐거나 다시 시도하고 싶을 때)
    static func clearSpineCache(isbn: String) {
        try? FileManager.default.removeItem(at: spineFile(isbn: isbn))
        try? FileManager.default.removeItem(at: spineMissMarker(isbn: isbn))
        memCache.removeObject(forKey: ("kspineraw|" + isbn) as NSString)
        rotatedCache.removeObject(forKey: ("kspine|" + isbn) as NSString)
    }

    /// 흰 캔버스 가운데 세로 책등 띠가 있으면 그 부분만 잘라 반환, 아니면 nil
    private static func cropSpineStrip(_ image: UIImage) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let sw = 100
        let sh = max(1, Int(CGFloat(sw) * CGFloat(cg.height) / CGFloat(cg.width)))
        var px = [UInt8](repeating: 0, count: sw * sh * 4)
        guard let ctx = CGContext(data: &px, width: sw, height: sh,
                                  bitsPerComponent: 8, bytesPerRow: sw * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.interpolationQuality = .low
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: sw, height: sh))

        // 흰색이 아닌 픽셀의 바운딩 박스
        var minX = sw, maxX = -1, minY = sh, maxY = -1
        for y in 0..<sh {
            for x in 0..<sw {
                let i = (y * sw + x) * 4
                let r = Int(px[i]), g = Int(px[i + 1]), b = Int(px[i + 2])
                if r > 242 && g > 242 && b > 242 { continue }
                if x < minX { minX = x }; if x > maxX { maxX = x }
                if y < minY { minY = y }; if y > maxY { maxY = y }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        let bw = maxX - minX + 1, bh = maxY - minY + 1

        // 책등 판정: 세로로 길쭉(폭/높이 < 0.35)하고 캔버스 높이 대부분을 차지
        guard CGFloat(bw) / CGFloat(bh) < 0.35, CGFloat(bh) > CGFloat(sh) * 0.55 else { return nil }

        // 원본 좌표로 환산해 크롭
        let scaleX = CGFloat(cg.width) / CGFloat(sw)
        let scaleY = CGFloat(cg.height) / CGFloat(sh)
        let rect = CGRect(x: CGFloat(minX) * scaleX,
                          y: CGFloat(minY) * scaleY,
                          width: CGFloat(bw) * scaleX,
                          height: CGFloat(bh) * scaleY).integral
        guard let cropped = cg.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cropped)
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
    @State private var realSpine: UIImage? = nil   // 교보 실제 책등 (회전 완료)

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
            // 책등 바탕: 실제 책등 > 표지 텍스처 > 테마 그라데이션
            Group {
                if useCoverTexture, let spine = realSpine {
                    // 실제 책등은 비율 유지 대신 늘려서 채움 (위아래 잘림 방지)
                    Image(uiImage: spine)
                        .resizable()
                } else if textureActive, let img = coverImage {
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

            // 실제 책등에는 제목이 이미 인쇄되어 있으므로 오버레이 생략
            if !(useCoverTexture && realSpine != nil) {
                Text(book.title ?? "")
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 12)
                    .shadow(color: darkSpine ? .black.opacity(0.35) : .white.opacity(0.25), radius: 1.5, x: 0, y: 1)
            }
        }
        .frame(height: h, alignment: .center)
        .clipped()
        .contentShape(Rectangle())
        .shadow(color: .black.opacity(0.07), radius: 3, x: 0, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.black.opacity(0.05), lineWidth: 0.8))
        .task(id: "\(book.isbn ?? "")|\(book.coverURL ?? "")|\(useCoverTexture)") {
            guard useCoverTexture else { return }
            // 1순위: 교보 실제 책등
            if let isbn = book.isbn, isbn.count == 13 {
                realSpine = await CoverImageStore.kyoboSpine(isbn: isbn)
                if realSpine != nil { return }
            }
            // 2순위: 표지 텍스처
            guard let s = book.coverURL, !s.isEmpty else { return }
            coverImage = await CoverImageStore.spineImage(for: s)
            coverDominant = await CoverColorExtractor.dominantColor(from: s)
        }
    }
}
