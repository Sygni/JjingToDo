//
//  PlantView.swift
//  JjingToDo
//
//  식물을 이미지가 아니라 도형으로 그린다 (BookStackView가 책등을 그리는 것과 같은 방식).
//  같은 seed면 항상 같은 모양이 나오므로 날짜를 seed로 쓰면 어제 본 정원이 그대로 남는다.
//

import SwiftUI

/// seed에서 0…1 난수를 뽑아내는 아주 작은 결정적 생성기
struct PlantRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }

    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((state >> 33) % 10_000) / 10_000
    }
    /// lo…hi 사이 값
    mutating func next(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat { lo + next() * (hi - lo) }
}

func plantSeed(date: Date, index: Int) -> UInt64 {
    UInt64(abs(Int(date.timeIntervalSince1970)) % 1_000_000) &* 97 &+ UInt64(index &* 31 &+ 7)
}

/// 식물 한 그루. height가 클수록 크게 자란다.
struct PlantView: View {
    let kind: PlantKind
    var seed: UInt64 = 1
    /// 희귀종 — 연속 보상. 색이 달라지고 반짝임이 붙는다
    var isRare: Bool = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Canvas { ctx, _ in
                var rng = PlantRandom(seed: seed)
                let lean = rng.next(-0.12, 0.12) * w
                switch kind {
                case .sprout:   drawSprout(&ctx, w: w, h: h, lean: lean, rng: &rng)
                case .flower:   drawFlower(&ctx, w: w, h: h, lean: lean, rng: &rng)
                case .mushroom: drawMushroom(&ctx, w: w, h: h, lean: lean, rng: &rng)
                case .tree:     drawTree(&ctx, w: w, h: h, lean: lean, rng: &rng)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isRare {
                    Image(systemName: "sparkle")
                        .font(.system(size: max(7, w * 0.22)))
                        .foregroundStyle(Color(hex: "#F2B705"))
                        .offset(x: -w * 0.05, y: h * 0.04)
                }
            }
        }
    }

    private var stemColor: Color { isRare ? Color(hex: "#5AA469") : Color(hex: "#6BA33A") }
    private var main: Color { isRare ? Color(hex: "#B98CE0") : kind.mainColor }
    private var sub: Color { isRare ? Color(hex: "#DCC6F2") : kind.subColor }

    // MARK: 종류별 그리기

    private func drawSprout(_ ctx: inout GraphicsContext, w: CGFloat, h: CGFloat,
                            lean: CGFloat, rng: inout PlantRandom) {
        let topY = h * rng.next(0.18, 0.34)
        var stem = Path()
        stem.move(to: CGPoint(x: w / 2, y: h))
        stem.addQuadCurve(to: CGPoint(x: w / 2 + lean, y: topY),
                          control: CGPoint(x: w / 2 + lean * 0.4, y: h * 0.6))
        ctx.stroke(stem, with: .color(stemColor), style: StrokeStyle(lineWidth: max(1.2, w * 0.07), lineCap: .round))

        let leafCount = Int(rng.next(2, 3.99))
        for i in 0..<leafCount {
            let t = CGFloat(i + 1) / CGFloat(leafCount + 1)
            let y = h - (h - topY) * t
            let side: CGFloat = (i % 2 == 0) ? -1 : 1
            let lw = w * rng.next(0.22, 0.34)
            let rect = CGRect(x: w / 2 + lean * t - lw / 2 + side * lw * 0.55,
                              y: y - lw * 0.22, width: lw, height: lw * 0.44)
            var leaf = Path(ellipseIn: rect)
            leaf = leaf.applying(CGAffineTransform(translationX: -rect.midX, y: -rect.midY)
                .concatenating(CGAffineTransform(rotationAngle: side * -0.5))
                .concatenating(CGAffineTransform(translationX: rect.midX, y: rect.midY)))
            ctx.fill(leaf, with: .color(i % 2 == 0 ? main : sub))
        }
    }

    private func drawFlower(_ ctx: inout GraphicsContext, w: CGFloat, h: CGFloat,
                            lean: CGFloat, rng: inout PlantRandom) {
        let topY = h * rng.next(0.26, 0.4)
        var stem = Path()
        stem.move(to: CGPoint(x: w / 2, y: h))
        stem.addQuadCurve(to: CGPoint(x: w / 2 + lean, y: topY),
                          control: CGPoint(x: w / 2 + lean * 0.3, y: h * 0.65))
        ctx.stroke(stem, with: .color(stemColor), style: StrokeStyle(lineWidth: max(1.1, w * 0.06), lineCap: .round))

        let lw = w * 0.26
        let leafRect = CGRect(x: w / 2 + lean * 0.4 - lw * 0.1, y: h * 0.62, width: lw, height: lw * 0.42)
        ctx.fill(Path(ellipseIn: leafRect), with: .color(Color(hex: "#8FBF4D")))

        let cx = w / 2 + lean
        let cy = topY
        let petals = Int(rng.next(5, 6.99))
        let pr = w * rng.next(0.15, 0.2)
        let ring = w * 0.16
        for i in 0..<petals {
            let a = (CGFloat(i) / CGFloat(petals)) * .pi * 2 + rng.next(-0.1, 0.1)
            let rect = CGRect(x: cx + cos(a) * ring - pr / 2, y: cy + sin(a) * ring - pr / 2,
                              width: pr, height: pr)
            ctx.fill(Path(ellipseIn: rect), with: .color(i % 2 == 0 ? main : sub))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: cx - w * 0.08, y: cy - w * 0.08, width: w * 0.16, height: w * 0.16)),
                 with: .color(Color(hex: "#F2C744")))
    }

    private func drawMushroom(_ ctx: inout GraphicsContext, w: CGFloat, h: CGFloat,
                              lean: CGFloat, rng: inout PlantRandom) {
        let capY = h * rng.next(0.34, 0.48)
        let stemW = w * rng.next(0.15, 0.21)
        let stem = Path(roundedRect: CGRect(x: w / 2 + lean * 0.5 - stemW / 2, y: capY,
                                            width: stemW, height: h - capY),
                        cornerRadius: stemW * 0.4)
        ctx.fill(stem, with: .color(sub))

        let capW = w * rng.next(0.62, 0.82)
        let capH = capW * rng.next(0.5, 0.66)
        let cx = w / 2 + lean * 0.5
        var cap = Path()
        cap.move(to: CGPoint(x: cx - capW / 2, y: capY))
        cap.addQuadCurve(to: CGPoint(x: cx + capW / 2, y: capY),
                         control: CGPoint(x: cx, y: capY - capH * 1.7))
        cap.closeSubpath()
        ctx.fill(cap, with: .color(main))

        let dots = Int(rng.next(2, 3.99))
        for _ in 0..<dots {
            let dx = rng.next(-0.3, 0.3) * capW
            let dy = rng.next(-0.55, -0.15) * capH
            let dr = w * rng.next(0.05, 0.09)
            ctx.fill(Path(ellipseIn: CGRect(x: cx + dx - dr, y: capY + dy - dr, width: dr * 2, height: dr * 2)),
                     with: .color(Color.white.opacity(0.85)))
        }
    }

    private func drawTree(_ ctx: inout GraphicsContext, w: CGFloat, h: CGFloat,
                          lean: CGFloat, rng: inout PlantRandom) {
        let trunkW = w * rng.next(0.13, 0.18)
        let trunkTop = h * rng.next(0.44, 0.56)
        let trunk = Path(roundedRect: CGRect(x: w / 2 - trunkW / 2, y: trunkTop,
                                             width: trunkW, height: h - trunkTop),
                         cornerRadius: trunkW * 0.3)
        ctx.fill(trunk, with: .color(Color(hex: "#8A5A34")))

        let cx = w / 2 + lean * 0.5
        let blobs: [(CGFloat, CGFloat, CGFloat)] = [
            (0, -0.1, 0.34), (-0.22, 0.06, 0.26), (0.22, 0.06, 0.26)
        ]
        for (i, b) in blobs.enumerated() {
            let r = w * b.2 * rng.next(0.9, 1.1)
            let bx = cx + b.0 * w
            let by = trunkTop + b.1 * h
            ctx.fill(Path(ellipseIn: CGRect(x: bx - r, y: by - r, width: r * 2, height: r * 2)),
                     with: .color(i == 0 ? main : (i == 1 ? Color(hex: "#2F7F5B") : sub)))
        }
    }
}

// MARK: - 화분 한 칸

/// 하루치 정원. 화분 위에 그날 심은 식물들이 모여 자란다.
struct DayPotView: View {
    let day: DayGarden
    /// 화분·흙까지 그릴지 (월간처럼 작을 땐 흙만)
    var showsPot: Bool = true

    private var visible: [PlantKind] {
        // 어려운 것부터 보여줘야 나무가 가려지지 않는다
        Array(day.plants.sorted { $0.rawValue > $1.rawValue }.prefix(5))
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let soilH = h * (showsPot ? 0.26 : 0.14)
            let plantArea = h - soilH

            ZStack(alignment: .bottom) {
                if day.moss > 0 {
                    // 챌린지(추구미) = 바닥 이끼
                    MossView(amount: day.moss)
                        .frame(height: soilH * 0.9)
                        .offset(y: -soilH * 0.55)
                }

                if visible.isEmpty {
                    Circle()
                        .fill(Color.secondary.opacity(0.18))
                        .frame(width: max(3, w * 0.08), height: max(3, w * 0.08))
                        .offset(y: -soilH - h * 0.06)
                } else {
                    let n = visible.count
                    ForEach(Array(visible.enumerated()), id: \.offset) { idx, kind in
                        let slot = n == 1 ? 0.5 : CGFloat(idx) / CGFloat(n - 1)
                        let x = w * (0.22 + slot * 0.56)
                        // 개수가 많을수록 조금씩 작게 그려 넘치지 않게
                        let scale = 1.0 - CGFloat(n) * 0.06
                        let ph = plantArea * (kind == .tree ? 0.95 : 0.82) * scale
                        PlantView(kind: kind,
                                  seed: plantSeed(date: day.date, index: idx),
                                  isRare: day.hasRarePlant && idx == 0)
                            .frame(width: w * 0.5 * scale, height: ph)
                            .position(x: x, y: h - soilH - ph / 2)
                    }
                }

                if showsPot {
                    PotShape()
                        .fill(Color(hex: "#C9764A"))
                        .frame(height: soilH)
                } else {
                    Rectangle()
                        .fill(Color(hex: "#B99A78").opacity(0.5))
                        .frame(height: soilH)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
            }
        }
    }
}

struct PotShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let lipH = rect.height * 0.3
        p.addRoundedRect(in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: lipH),
                         cornerSize: CGSize(width: 2, height: 2))
        let inset = rect.width * 0.09
        p.move(to: CGPoint(x: rect.minX + inset, y: rect.minY + lipH))
        p.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY + lipH))
        p.addLine(to: CGPoint(x: rect.maxX - inset * 2.2, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + inset * 2.2, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// 챌린지 활동량만큼 깔리는 이끼
struct MossView: View {
    let amount: Int

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                var rng = PlantRandom(seed: UInt64(amount) &* 7919 &+ 13)
                let blobs = min(amount * 2, 10)
                for _ in 0..<blobs {
                    let r = size.width * rng.next(0.07, 0.14)
                    let x = rng.next(0.08, 0.92) * size.width
                    let y = rng.next(0.35, 0.9) * size.height
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r * 0.6, width: r * 2, height: r * 1.2)),
                             with: .color(Color(hex: "#7FB069").opacity(0.55)))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
