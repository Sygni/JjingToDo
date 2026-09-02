//
//  BookTheme.swift
//  JjingToDo
//  책 UI 전용 색상/스파인 두께 계산 (JjingBook에서 이식)
//

import SwiftUI

enum Palette {
    static let koTop    = Color(hex: "#B5E5D5")
    static let koBottom = Color(hex: "#74CBB8")
    static let enTop    = Color(hex: "#FFE566")
    static let enBottom = Color(hex: "#F5C200")
    static let enAccent = Color(hex: "#A07000")
    static let stroke   = Color.white.opacity(0.28)
    static let shadow   = Color.black.opacity(0.10)
    static let textDark = Color(hex: "#1B1C1E")
    static let titleIcon = Color(hex: "A6C1E1")
    static let titleFont = Color(hex: "4A5665")
}

enum SpineCurve {
    case linear(CGFloat)
    case sqrt(CGFloat)
    case log(CGFloat)
    case cbrt(CGFloat)
}

struct SpineConfig {
    static var curve: SpineCurve = .linear(0.12)
    static var minH: CGFloat = 12
    static var maxH: CGFloat? = nil
    static var langMulKO: CGFloat = 1.0
    static var langMulForeign: CGFloat = 1.3

    /// 쪽수 1쪽당 (두께 ÷ 책 높이) 비율.
    /// 교보 실제 책등 이미지 6권을 실측해 얻은 중앙값 — 1000쪽당 0.299
    static var thicknessPerPage: CGFloat = 0.000299
    /// 실제 책등 이미지 비율을 얼마나 반영할지 (0 = 쪽수만, 1 = 이미지 비율만)
    static var defaultAspectBlend: CGFloat = 0.5
    static var minThickness: CGFloat = 10
    static var maxThickness: CGFloat = 95
}

/// 눕혀 쌓은 책의 두께(=화면상 높이) 계산.
/// - Parameters:
///   - bookWidth: 화면에 그려지는 책의 폭 (= 책의 실제 높이에 해당)
///   - imageAspect: 실제 책등 이미지의 두께/높이 비율. 이미지가 없으면 nil
///   - blend: 이미지 비율 반영 정도 (0…1)
func spineThickness(pages: Int32,
                    isKorean: Bool,
                    bookWidth: CGFloat,
                    imageAspect: CGFloat?,
                    blend: CGFloat = SpineConfig.defaultAspectBlend) -> CGFloat {
    let p = CGFloat(max(1, Int(pages)))
    let langMul = isKorean ? SpineConfig.langMulKO : SpineConfig.langMulForeign
    let fromPages = bookWidth * p * SpineConfig.thicknessPerPage * langMul

    var result = fromPages
    if let aspect = imageAspect, aspect.isFinite, aspect > 0.001 {
        let fromImage = bookWidth * aspect
        let a = min(max(blend, 0), 1)
        // 기하 혼합 — 한쪽이 극단적이어도 완만하게 섞인다
        result = pow(fromPages, 1 - a) * pow(fromImage, a)
        // 크롭이 잘못돼도 쪽수 기준에서 크게 벗어나지 않도록 제한
        result = min(max(result, fromPages * 0.6), fromPages * 1.7)
    }
    guard result.isFinite else { return SpineConfig.minThickness }
    return min(max(result, SpineConfig.minThickness), SpineConfig.maxThickness)
        .rounded(.toNearestOrAwayFromZero)
}

@inline(__always)
func spineHeight(pages: Int32, isKorean: Bool, effort: CGFloat = 1.0) -> CGFloat {
    let p = max(1, Int(pages))
    let base: CGFloat
    switch SpineConfig.curve {
    case .linear(let k): base = CGFloat(p) * k
    case .sqrt(let k):   base = sqrt(CGFloat(p)) * k
    case .log(let k):    base = log1p(CGFloat(p)) * k
    case .cbrt(let k):   base = pow(CGFloat(p), 1.0/3.0) * k
    }
    let langMul = isKorean ? SpineConfig.langMulKO : SpineConfig.langMulForeign
    var h = max(SpineConfig.minH, base * langMul * effort)
    if let cap = SpineConfig.maxH { h = min(h, cap) }
    return h.rounded(.toNearestOrAwayFromZero)
}

func stableJitter(from key: String) -> (rotation: Double, offsetX: CGFloat) {
    var hash = UInt64(1469598103934665603)
    for u in key.unicodeScalars { hash ^= UInt64(u.value); hash &*= 1099511628211 }
    let rot = Double(Int64(hash & 0x7) - 3)
    let off = CGFloat(Int64((hash >> 3) & 0xF) - 8)
    return (rot, off)
}

func startOffsetX(from key: String, maxJitter: CGFloat = 24) -> CGFloat {
    var hash = UInt64(1469598103934665603)
    for u in key.unicodeScalars { hash = (hash ^ UInt64(u.value)) &* 1099511628211 }
    let t = Double(hash % 10_000) / 10_000.0
    return CGFloat((t * 2.0 - 1.0)) * maxJitter
}
