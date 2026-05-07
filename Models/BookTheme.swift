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
