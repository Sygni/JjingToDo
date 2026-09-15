//
//  GardenPlotView.swift
//  JjingToDo
//
//  한 주 동안 심은 식물을 한 화단에 모아 심은 모습 (Forest 주간 뷰 스타일).
//  아이소메트릭 격자에 뒤쪽 칸부터 그려서 앞의 식물이 뒤를 자연스럽게 가린다.
//

import SwiftUI

// MARK: - 격자 계산

struct PlotLayout {
    let width: CGFloat
    let grid: Int

    var diamondW: CGFloat { width * 0.92 }
    var tileW: CGFloat { diamondW / CGFloat(grid) }
    var tileH: CGFloat { tileW * 0.5 }
    /// 맨 뒤 칸에 나무가 서도 잘리지 않을 만큼의 윗여백
    var topPad: CGFloat { tileW * 1.45 }
    var thickness: CGFloat { tileH * 0.9 }
    var originX: CGFloat { width / 2 }

    func cellCenter(col: Int, row: Int) -> CGPoint {
        CGPoint(x: originX + CGFloat(col - row) * tileW / 2,
                y: topPad + CGFloat(col + row + 1) * tileH / 2)
    }

    func tilePath(col: Int, row: Int) -> Path {
        let c = cellCenter(col: col, row: row)
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - tileH / 2))
        p.addLine(to: CGPoint(x: c.x + tileW / 2, y: c.y))
        p.addLine(to: CGPoint(x: c.x, y: c.y + tileH / 2))
        p.addLine(to: CGPoint(x: c.x - tileW / 2, y: c.y))
        p.closeSubpath()
        return p
    }

    /// 심은 수에 맞춰 격자를 키운다 — 빽빽하지도 휑하지도 않게.
    /// 한 주 최대 5×7=35포기면 8×8.
    static func gridSize(for count: Int) -> Int {
        let g = Int(ceil(sqrt(Double(max(count, 1)) * 1.7)))
        return min(max(g, 4), 8)
    }

    /// 너비 대비 전체 높이 (윗여백 + 윗면 + 흙 두께 + 아래 여백)
    static func heightRatio(grid: Int) -> CGFloat {
        let g = CGFloat(grid)
        let tileW = 0.92 / g
        let tileH = tileW * 0.5
        return tileW * 1.45 + tileH * g + tileH * 0.9 + tileH * 0.5
    }
}

// MARK: - 모아심기 화단

struct WeekPlotView: View {
    /// 그 주의 7일 (빈 날 포함)
    let days: [DayGarden]
    /// 배치를 고정하는 기준 — 같은 주는 언제 열어도 같은 자리에 심겨 있다
    let seedDate: Date

    private struct Placement: Identifiable {
        let id: Int
        let col: Int
        let row: Int
        let kind: PlantKind
        let variant: PlantVariant
        let seed: UInt64
    }

    private struct Arrangement {
        var placements: [Placement] = []
        var moss: [(col: Int, row: Int)] = []
        var grass: [(col: Int, row: Int)] = []
        var overflow: Int = 0
    }

    private var entries: [(date: Date, plant: OrderedPlant)] {
        days.flatMap { day in day.orderedPlants().map { (date: day.date, plant: $0) } }
    }

    var body: some View {
        let all = entries
        let g = PlotLayout.gridSize(for: all.count)
        let plan = arrange(all, grid: g)

        GeometryReader { geo in
            let layout = PlotLayout(width: geo.size.width, grid: g)
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    drawBoard(&ctx, layout: layout, plan: plan)
                }
                // 뒤쪽 칸부터 정렬돼 있어 나중에 그린 앞 식물이 뒤를 가린다
                ForEach(plan.placements) { p in
                    let c = layout.cellCenter(col: p.col, row: p.row)
                    let pw = layout.tileW * 1.05
                    let ph = layout.tileW * 1.55 * p.kind.heightFactor
                    PlantView(kind: p.kind, seed: p.seed, variant: p.variant)
                        .frame(width: pw, height: ph)
                        .position(x: c.x, y: c.y - ph / 2 + layout.tileH * 0.15)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if plan.overflow > 0 {
                    Text("+\(plan.overflow)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color(.systemBackground).opacity(0.8)))
                }
            }
        }
        .aspectRatio(1 / PlotLayout.heightRatio(grid: g), contentMode: .fit)
    }

    // MARK: 배치

    private func arrange(_ all: [(date: Date, plant: OrderedPlant)], grid g: Int) -> Arrangement {
        var rng = PlantRandom(seed: UInt64(abs(Int(seedDate.timeIntervalSince1970)) % 1_000_000) &+ 101)

        // 칸 순서를 섞는다 (Fisher–Yates)
        var cells = Array(0..<(g * g))
        if cells.count > 1 {
            for i in stride(from: cells.count - 1, to: 0, by: -1) {
                let j = min(i, Int(rng.next() * CGFloat(i + 1)))
                cells.swapAt(i, j)
            }
        }

        // 넘칠 때는 특별한 개체와 큰 식물을 우선 남긴다
        let ranked = all.sorted { a, b in
            let sa = a.plant.variant != .normal
            let sb = b.plant.variant != .normal
            if sa != sb { return sa }
            return a.plant.item.kind.rawValue > b.plant.item.kind.rawValue
        }
        let shownCount = min(ranked.count, cells.count)

        var plan = Arrangement()
        plan.overflow = ranked.count - shownCount

        // 키 큰 식물을 뒤쪽 칸에 — 작은 식물이 가려지지 않는다
        let chosen = cells.prefix(shownCount).sorted { ($0 % g + $0 / g) < ($1 % g + $1 / g) }
        let tallFirst = ranked.prefix(shownCount).sorted {
            $0.plant.item.kind.heightFactor > $1.plant.item.kind.heightFactor
        }

        plan.placements = zip(chosen, tallFirst).enumerated().map { i, pair in
            let (cell, entry) = pair
            return Placement(id: i, col: cell % g, row: cell / g,
                             kind: entry.plant.item.kind,
                             variant: entry.plant.variant,
                             seed: plantSeed(date: entry.date, index: entry.plant.index))
        }
        .sorted { ($0.col + $0.row, $0.col) < ($1.col + $1.row, $1.col) }

        // 빈 칸: 챌린지 이끼를 먼저, 나머지엔 드문드문 짧은 풀
        let empty = Array(cells.dropFirst(shownCount))
        let weekMoss = days.reduce(0) { $0 + $1.moss }
        let mossCount = min(empty.count, (weekMoss + 1) / 2)
        plan.moss = empty.prefix(mossCount).map { (col: $0 % g, row: $0 / g) }
        plan.grass = empty.dropFirst(mossCount).enumerated()
            .filter { $0.offset % 2 == 0 }
            .map { (col: $0.element % g, row: $0.element / g) }
        return plan
    }

    // MARK: 화단 그리기

    private func drawBoard(_ ctx: inout GraphicsContext, layout L: PlotLayout, plan: Arrangement) {
        let g = CGFloat(L.grid)
        let right = CGPoint(x: L.originX + g * L.tileW / 2, y: L.topPad + g * L.tileH / 2)
        let bottom = CGPoint(x: L.originX, y: L.topPad + g * L.tileH)
        let left = CGPoint(x: L.originX - g * L.tileW / 2, y: L.topPad + g * L.tileH / 2)
        let t = L.thickness

        func side(_ a: CGPoint, _ b: CGPoint, depth d: CGFloat) -> Path {
            var p = Path()
            p.move(to: a)
            p.addLine(to: b)
            p.addLine(to: CGPoint(x: b.x, y: b.y + d))
            p.addLine(to: CGPoint(x: a.x, y: a.y + d))
            p.closeSubpath()
            return p
        }

        // 흙 옆면 — 왼쪽은 밝게, 오른쪽은 어둡게
        ctx.fill(side(left, bottom, depth: t), with: .color(Color(hex: "#9A6B43")))
        ctx.fill(side(bottom, right, depth: t), with: .color(Color(hex: "#7E5434")))

        // 흙 알갱이
        var rng = PlantRandom(seed: 29)
        for _ in 0..<(L.grid * 3) {
            let onLeft = rng.next() > 0.5
            let u = rng.next(0.05, 0.95)
            let v = rng.next(0.45, 0.9)
            let a = onLeft ? left : bottom
            let b = onLeft ? bottom : right
            let px = a.x + (b.x - a.x) * u
            let py = a.y + (b.y - a.y) * u + t * v
            let rr = L.tileH * rng.next(0.06, 0.12)
            ctx.fill(Path(ellipseIn: CGRect(x: px - rr * 1.4, y: py - rr, width: rr * 2.8, height: rr * 2)),
                     with: .color(Color(hex: "#6A4429").opacity(0.55)))
        }

        // 옆면 위쪽 잔디 테두리
        ctx.fill(side(left, bottom, depth: t * 0.3), with: .color(Color(hex: "#86B947")))
        ctx.fill(side(bottom, right, depth: t * 0.3), with: .color(Color(hex: "#74A23B")))

        // 윗면 잔디 — 칸마다 살짝 다른 초록으로 체크무늬
        for r in 0..<L.grid {
            for c in 0..<L.grid {
                let shade = (c + r) % 2 == 0 ? Color(hex: "#A7D35B") : Color(hex: "#9DCA52")
                ctx.fill(L.tilePath(col: c, row: r), with: .color(shade))
            }
        }

        // 빈 칸의 짧은 풀
        for cell in plan.grass {
            let ctr = L.cellCenter(col: cell.col, row: cell.row)
            let s = L.tileH * 0.22
            var p = Path()
            p.move(to: CGPoint(x: ctr.x - s * 0.6, y: ctr.y))
            p.addLine(to: CGPoint(x: ctr.x - s * 0.2, y: ctr.y - s))
            p.move(to: CGPoint(x: ctr.x + s * 0.1, y: ctr.y + s * 0.1))
            p.addLine(to: CGPoint(x: ctr.x + s * 0.5, y: ctr.y - s * 0.9))
            ctx.stroke(p, with: .color(Color(hex: "#7FAE3E")),
                       style: StrokeStyle(lineWidth: max(0.8, L.tileW * 0.02), lineCap: .round))
        }

        // 챌린지(추구미) = 이끼
        for cell in plan.moss {
            let ctr = L.cellCenter(col: cell.col, row: cell.row)
            for k in 0..<3 {
                let ox = CGFloat(k - 1) * L.tileW * 0.13
                let oy = CGFloat(k % 2) * L.tileH * 0.1
                let rect = CGRect(x: ctr.x + ox - L.tileW * 0.11, y: ctr.y - L.tileH * 0.13 + oy,
                                  width: L.tileW * 0.22, height: L.tileH * 0.26)
                ctx.fill(Path(ellipseIn: rect), with: .color(Color(hex: "#5E8F3A").opacity(0.8)))
            }
        }
    }
}
