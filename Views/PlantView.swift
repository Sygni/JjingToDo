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

enum PlantVariant {
    case normal
    case rare      // 연속 7일 — 보라빛
    case golden    // 등급 상승 — 황금빛
}

/// 식물 한 그루. height가 클수록 크게 자란다.
struct PlantView: View {
    let kind: PlantKind
    var seed: UInt64 = 1
    var variant: PlantVariant = .normal

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
                switch variant {
                case .normal:
                    EmptyView()
                case .rare:
                    Image(systemName: "sparkle")
                        .font(.system(size: max(7, w * 0.22)))
                        .foregroundStyle(Color(hex: "#A87BE0"))
                        .offset(x: -w * 0.05, y: h * 0.04)
                case .golden:
                    Image(systemName: "sparkles")
                        .font(.system(size: max(8, w * 0.26)))
                        .foregroundStyle(Color(hex: "#E8B23A"))
                        .offset(x: -w * 0.02, y: h * 0.02)
                }
            }
        }
    }

    private var stemColor: Color {
        switch variant {
        case .normal: return Color(hex: "#6BA33A")
        case .rare:   return Color(hex: "#5AA469")
        case .golden: return Color(hex: "#9C8A3E")
        }
    }
    private var main: Color {
        switch variant {
        case .normal: return kind.mainColor
        case .rare:   return Color(hex: "#B98CE0")
        case .golden: return Color(hex: "#E8B23A")
        }
    }
    private var sub: Color {
        switch variant {
        case .normal: return kind.subColor
        case .rare:   return Color(hex: "#DCC6F2")
        case .golden: return Color(hex: "#F7DE93")
        }
    }
    /// 나무 수관처럼 여러 단계가 필요한 곳에서 쓰는 색
    private func shade(_ level: Int) -> Color {
        switch variant {
        case .normal: return [kind.mainColor, Color(hex: "#2F7F5B"), kind.subColor][level % 3]
        case .rare:   return [Color(hex: "#B98CE0"), Color(hex: "#8E63C4"), Color(hex: "#DCC6F2")][level % 3]
        case .golden: return [Color(hex: "#E8B23A"), Color(hex: "#C9922A"), Color(hex: "#F7DE93")][level % 3]
        }
    }

    // MARK: 종류별 그리기

    /// 뾰족한 끝을 가진 잎 — 원점에서 +x 방향으로 자란다
    private func leafPath(length: CGFloat, width: CGFloat) -> Path {
        var p = Path()
        p.move(to: .zero)
        p.addQuadCurve(to: CGPoint(x: length, y: 0),
                       control: CGPoint(x: length * 0.45, y: -width * 0.62))
        p.addQuadCurve(to: .zero,
                       control: CGPoint(x: length * 0.45, y: width * 0.62))
        return p
    }

    private func placeLeaf(_ path: Path, at point: CGPoint, angle: CGFloat) -> Path {
        path.applying(CGAffineTransform(rotationAngle: angle)
            .concatenating(CGAffineTransform(translationX: point.x, y: point.y)))
    }

    /// 새싹 — 짧은 줄기 끝에 떡잎 두 장이 V자로. 🌱 모양에 가깝게
    private func drawSprout(_ ctx: inout GraphicsContext, w: CGFloat, h: CGFloat,
                            lean: CGFloat, rng: inout PlantRandom) {
        let spread = rng.next(0.36, 0.5)
        let len = min(w * 0.46, h * 0.5)
        // 잎이 위로 뻗는 만큼을 빼서 줄기 끝을 정하면 잎 끝이 항상 프레임 상단에 닿는다
        let topY = len * cos(spread) + h * 0.05
        let topX = w / 2 + lean * 0.6

        var stem = Path()
        stem.move(to: CGPoint(x: w / 2, y: h))
        stem.addQuadCurve(to: CGPoint(x: topX, y: topY),
                          control: CGPoint(x: w / 2 + lean * 0.2, y: h * 0.72))
        ctx.stroke(stem, with: .color(stemColor),
                   style: StrokeStyle(lineWidth: max(1.3, w * 0.075), lineCap: .round))

        let top = CGPoint(x: topX, y: topY)
        let thick = len * rng.next(0.62, 0.78)

        // 좌우 떡잎 — 위쪽 바깥으로 벌어진다
        ctx.fill(placeLeaf(leafPath(length: len, width: thick), at: top,
                           angle: -(.pi / 2) - spread), with: .color(main))
        ctx.fill(placeLeaf(leafPath(length: len * rng.next(0.9, 1.05), width: thick), at: top,
                           angle: -(.pi / 2) + spread), with: .color(sub))

        // 가끔 작은 잎이 하나 더 — 같은 종이라도 조금씩 다르게 보이도록
        if rng.next() > 0.55 {
            let side: CGFloat = rng.next() > 0.5 ? 1 : -1
            let at = CGPoint(x: topX - lean * 0.2, y: topY + (h - topY) * rng.next(0.3, 0.5))
            ctx.fill(placeLeaf(leafPath(length: len * 0.52, width: thick * 0.6), at: at,
                               angle: side > 0 ? -0.5 : .pi + 0.5),
                     with: .color(side > 0 ? sub : main))
        }
    }

    private func drawFlower(_ ctx: inout GraphicsContext, w: CGFloat, h: CGFloat,
                            lean: CGFloat, rng: inout PlantRandom) {
        // 링 반지름보다 꽃잎이 크면 서로 뭉쳐 개수가 안 보인다 — 링을 넓히고 꽃잎은 작게
        // 링을 줄이고 꽃잎을 키워 안쪽 끝이 가운데 노란 부분에 닿게 한다
        let ring = min(w * rng.next(0.21, 0.24), h * 0.26)
        let pr = min(w * rng.next(0.18, 0.21), h * 0.2)
        let topY = ring + pr * 0.62 + h * 0.04
        var stem = Path()
        stem.move(to: CGPoint(x: w / 2, y: h))
        stem.addQuadCurve(to: CGPoint(x: w / 2 + lean, y: topY),
                          control: CGPoint(x: w / 2 + lean * 0.3, y: h * 0.65))
        ctx.stroke(stem, with: .color(stemColor), style: StrokeStyle(lineWidth: max(1.1, w * 0.06), lineCap: .round))

        // 줄기 양쪽에 잎 두 장 — 높이를 달리해 자연스럽게
        let leafLen = min(w * 0.32, (h - topY) * 0.42)
        let rightAt = CGPoint(x: w / 2 + lean * 0.45, y: topY + (h - topY) * rng.next(0.34, 0.44))
        ctx.fill(placeLeaf(leafPath(length: leafLen, width: leafLen * 0.56), at: rightAt, angle: -0.62),
                 with: .color(Color(hex: "#8FBF4D")))
        let leftAt = CGPoint(x: w / 2 + lean * 0.25, y: topY + (h - topY) * rng.next(0.6, 0.72))
        ctx.fill(placeLeaf(leafPath(length: leafLen * 0.88, width: leafLen * 0.5), at: leftAt,
                           angle: .pi + 0.62),
                 with: .color(Color(hex: "#7FB03F")))

        let cx = w / 2 + lean
        let cy = topY
        let petals = Int(rng.next(7, 9.99))
        for i in 0..<petals {
            let a = (CGFloat(i) / CGFloat(petals)) * .pi * 2 + rng.next(-0.05, 0.05)
            // 바깥을 향해 길쭉한 타원 — 원보다 꽃잎처럼 읽힌다
            let rect = CGRect(x: ring - pr * 0.62, y: -pr * 0.42,
                              width: pr * 1.24, height: pr * 0.84)
            let petal = Path(ellipseIn: rect)
                .applying(CGAffineTransform(rotationAngle: a)
                    .concatenating(CGAffineTransform(translationX: cx, y: cy)))
            ctx.fill(petal, with: .color(i % 2 == 0 ? main : sub))
        }
        let coreR = min(ring * 0.42, w * 0.09)
        ctx.fill(Path(ellipseIn: CGRect(x: cx - coreR, y: cy - coreR,
                                        width: coreR * 2, height: coreR * 2)),
                 with: .color(Color(hex: "#F2C744")))
    }

    private func drawMushroom(_ ctx: inout GraphicsContext, w: CGFloat, h: CGFloat,
                              lean: CGFloat, rng: inout PlantRandom) {
        let capW = w * rng.next(0.9, 1.0)
        let capH = min(capW * rng.next(0.62, 0.78), h * 0.52)
        // 2차 곡선의 꼭대기는 제어점의 약 3/4 지점
        let capY = capH * 1.28 + h * 0.03
        let stemW = capW * rng.next(0.3, 0.38)
        let stem = Path(roundedRect: CGRect(x: w / 2 + lean * 0.25 - stemW / 2, y: capY,
                                            width: stemW, height: h - capY),
                        cornerRadius: stemW * 0.4)
        ctx.fill(stem, with: .color(sub))

        let cx = w / 2 + lean * 0.25
        var cap = Path()
        cap.move(to: CGPoint(x: cx - capW / 2, y: capY))
        cap.addQuadCurve(to: CGPoint(x: cx + capW / 2, y: capY),
                         control: CGPoint(x: cx, y: capY - capH * 1.7))
        cap.closeSubpath()
        ctx.fill(cap, with: .color(main))

        let dots = Int(rng.next(3, 4.99))
        for _ in 0..<dots {
            let dx = rng.next(-0.28, 0.28) * capW
            let dy = rng.next(-0.6, -0.18) * capH
            let dr = capW * rng.next(0.07, 0.11)
            ctx.fill(Path(ellipseIn: CGRect(x: cx + dx - dr, y: capY + dy - dr, width: dr * 2, height: dr * 2)),
                     with: .color(Color.white.opacity(0.85)))
        }
    }

    private func drawTree(_ ctx: inout GraphicsContext, w: CGFloat, h: CGFloat,
                          lean: CGFloat, rng: inout PlantRandom) {
        let trunkW = w * rng.next(0.13, 0.18)
        let canopyR = min(w * 0.34, h * 0.34)
        let trunkTop = canopyR + h * 0.13
        let trunk = Path(roundedRect: CGRect(x: w / 2 - trunkW / 2, y: trunkTop,
                                             width: trunkW, height: h - trunkTop),
                         cornerRadius: trunkW * 0.3)
        ctx.fill(trunk, with: .color(Color(hex: "#8A5A34")))

        let cx = w / 2 + lean * 0.5
        // (x비율, y비율, 반지름비율) — 아래쪽 잎 뭉치를 더해 중간까지 채운다
        let blobs: [(CGFloat, CGFloat, CGFloat)] = [
            (0,     -0.10, 0.34),
            (-0.24,  0.05, 0.27), (0.24,  0.05, 0.27),
            (-0.15,  0.20, 0.23), (0.15,  0.20, 0.23),
            (0,      0.30, 0.20)
        ]

        let usedBlobs = Array(blobs.prefix(Int(rng.next(5, 6.99))))
        for (i, b) in usedBlobs.enumerated() {
            let r = w * b.2 * rng.next(0.9, 1.08)
            let bx = cx + b.0 * w + rng.next(-0.04, 0.04) * w
            let by = trunkTop + b.1 * h + rng.next(-0.03, 0.03) * h
            ctx.fill(Path(ellipseIn: CGRect(x: bx - r, y: by - r, width: r * 2, height: r * 2)),
                     with: .color(shade(i)))
        }
    }
}

// MARK: - 화분 한 칸

/// 하루치 정원. 화분 위에 그날 심은 식물들이 모여 자란다.
struct DayPotView: View {
    let day: DayGarden
    /// 화분·흙까지 그릴지 (월간처럼 작을 땐 흙만)
    var showsPot: Bool = true

    /// 하루 5포기 정도는 빽빽해도 보여준다 — 그날 많이 한 게 보이는 게 낫다
    private func capacity(width: CGFloat) -> Int {
        switch width {
        case ..<38:  return 4
        case ..<120: return 5
        default:     return 6
        }
    }

    private func visible(width: CGFloat) -> [PlantedItem] {
        // 등급을 올려준 식물과 어려운 것부터 — 특별한 게 가려지지 않게
        let sorted = day.plants.sorted {
            if $0.isLevelUp != $1.isLevelUp { return $0.isLevelUp }
            return $0.kind.rawValue > $1.kind.rawValue
        }
        return Array(sorted.prefix(capacity(width: width)))
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let soilH = h * (showsPot ? 0.26 : 0.14)
            let plantArea = h - soilH
            let shown = visible(width: w)
            let hidden = day.plants.count - shown.count

            ZStack(alignment: .bottom) {
                if day.moss > 0 {
                    // 챌린지(추구미) = 바닥 이끼
                    MossView(amount: day.moss)
                        .frame(height: soilH * 0.9)
                        .offset(y: -soilH * 0.55)
                }

                if shown.isEmpty {
                    // 아무것도 심지 않은 날 — 화분이 엎어져 있다
                    PotShape()
                        .fill(Color(hex: "#B08968").opacity(0.35))
                        .rotationEffect(.degrees(180))
                        .frame(width: w * 0.44, height: soilH * (showsPot ? 0.9 : 1.6))
                        .offset(y: -soilH * (showsPot ? 0.95 : 0.85))
                } else {
                    let n = shown.count
                    // 전체 폭의 92%를 나눠 쓰게 해서 포기 수가 늘어도 겹치지 않는다
                    let slotW = w * 0.92 / CGFloat(n)
                    let plantW = min(w * 0.52, slotW * 1.2)
                    // 빽빽할수록 살짝만 낮춘다 (너무 줄이면 키 순서가 뭉개진다)
                    let heightScale = n <= 3 ? 1.0 : 1.0 - CGFloat(n - 3) * 0.04

                    ForEach(Array(shown.enumerated()), id: \.offset) { idx, item in
                        let x = w * 0.04 + slotW * (CGFloat(idx) + 0.5)
                        // 난이도 순으로 키가 커진다 (새싹 < 꽃 < 버섯 < 나무)
                        let ph = plantArea * item.kind.heightFactor * heightScale
                        PlantView(kind: item.kind,
                                  seed: plantSeed(date: day.date, index: idx),
                                  variant: item.isLevelUp ? .golden
                                           : (day.hasRarePlant && idx == 0 ? .rare : .normal))
                            .frame(width: plantW, height: ph)
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
            // 식물이 없으면 ZStack이 화분 높이로 줄어들어 위로 떠버린다 — 높이를 고정
            .frame(width: w, height: h, alignment: .bottom)
            .overlay(alignment: .topTrailing) {
                if hidden > 0, w >= 40 {
                    Text("+\(hidden)")
                        .font(.system(size: max(8, w * 0.13), weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 3)
                        .background(Capsule().fill(Color(.systemBackground).opacity(0.7)))
                        .padding(2)
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
