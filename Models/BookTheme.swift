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

    /// 실제 책등 이미지 비율을 얼마나 반영할지 (0 = 실측/쪽수만, 1 = 이미지 비율만)
    static var defaultAspectBlend: CGFloat = 0.5
    static var minThickness: CGFloat = 10
    static var maxThickness: CGFloat = 95
}

/// 실측 판형(mm) 기반 렌더링 기준값.
/// 알라딘 packing 정보를 13권 조사한 결과 — 높이 175~225mm(중앙값 205), 쪽당 0.0565mm
struct BookMetrics {
    /// 이 높이의 책이 기준 폭으로 그려진다
    static let referenceHeightMM: CGFloat = 205
    /// 판형을 모를 때 가정하는 높이
    static let defaultHeightMM: CGFloat = 205
    /// 두께를 모를 때 쪽수로 추정하는 계수
    static let mmPerPage: CGFloat = 0.0565
    /// 기준 폭 = 화면 폭의 이 비율
    static let widthFraction: CGFloat = 0.72
    static let maxWidth: CGFloat = 360
    /// 판형 차이가 과해지지 않도록 폭 변동 범위 제한
    static let widthRange: ClosedRange<CGFloat> = 0.78...1.15
}

/// 판형(높이 mm)에 따라 달라지는 책의 렌더링 폭
func bookRenderWidth(heightMM: Int16, containerWidth: CGFloat) -> CGFloat {
    let baseW = min(containerWidth * BookMetrics.widthFraction, BookMetrics.maxWidth)
    guard heightMM > 0 else { return baseW }
    let ratio = CGFloat(heightMM) / BookMetrics.referenceHeightMM
    let clamped = min(max(ratio, BookMetrics.widthRange.lowerBound), BookMetrics.widthRange.upperBound)
    return baseW * clamped
}

/// 눕혀 쌓은 책의 두께(=화면상 높이).
/// 실측 두께(mm)가 있으면 판형과의 실제 비율을 그대로 쓰고, 없으면 쪽수로 추정한다.
func spineThickness(pages: Int32,
                    thicknessMM: Int16,
                    heightMM: Int16,
                    isKorean: Bool,
                    bookWidth: CGFloat,
                    imageAspect: CGFloat?,
                    blend: CGFloat = SpineConfig.defaultAspectBlend) -> CGFloat {
    let hMM = heightMM > 0 ? CGFloat(heightMM) : BookMetrics.defaultHeightMM
    let tMM: CGFloat = {
        if thicknessMM > 0 { return CGFloat(thicknessMM) }
        let langMul = isKorean ? SpineConfig.langMulKO : SpineConfig.langMulForeign
        return CGFloat(max(1, Int(pages))) * BookMetrics.mmPerPage * langMul
    }()

    let fromPhysical = bookWidth * (tMM / hMM)
    var result = fromPhysical

    // 책등 이미지 비율과 섞기 — 크롭 여백 때문에 이미지 쪽이 조금 두껍게 나오는 편
    if let aspect = imageAspect, aspect.isFinite, aspect > 0.001 {
        let a = min(max(blend, 0), 1)
        result = pow(fromPhysical, 1 - a) * pow(bookWidth * aspect, a)
        result = min(max(result, fromPhysical * 0.6), fromPhysical * 1.7)
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
