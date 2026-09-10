//
//  GardenView.swift
//  JjingToDo
//

import SwiftUI
import CoreData

enum GardenScope: String, CaseIterable, Identifiable {
    case day = "일", week = "주", month = "월", year = "년"
    var id: String { rawValue }
}

struct GardenView: View {
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(entity: TaskEntity.entity(), sortDescriptors: [])
    private var tasks: FetchedResults<TaskEntity>
    @FetchRequest(entity: ChugumiActionEntity.entity(), sortDescriptors: [])
    private var mossActions: FetchedResults<ChugumiActionEntity>

    @State private var scope: GardenScope = .month
    /// 기준 날짜 — 이전/다음 버튼으로 옮긴다
    @State private var anchor: Date = GardenStats.today

    private var garden: [Date: DayGarden] {
        GardenStats.build(tasks: Array(tasks), moss: Array(mossActions))
    }
    private var rank: GardenRank {
        GardenRank.make(planted: GardenStats.plantedCount(tasks: Array(tasks)))
    }
    private var streak: StreakInfo { GardenStats.streak(tasks: Array(tasks)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    rankCard
                    Picker("범위", selection: $scope) {
                        ForEach(GardenScope.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    periodHeader

                    Group {
                        switch scope {
                        case .day:   dayView
                        case .week:  weekView
                        case .month: monthView
                        case .year:  yearView
                        }
                    }
                    .padding(.horizontal)

                    legend
                }
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("나의 정원")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() } }
            }
        }
    }

    // MARK: 등급 카드

    private var rankCard: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(rank.title).font(.title3.bold())
                Text("\(rank.stage)단계").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                if streak.current > 0 {
                    Label("\(streak.current)일", systemImage: "flame.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "#E2703A"))
                }
            }
            ProgressView(value: rank.progress)
                .tint(Color(hex: "#3E9B6E"))
            HStack {
                Text("심은 식물 \(rank.planted)그루")
                Spacer()
                Text("다음 단계까지 \(rank.remaining)그루")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if streak.best > 0 {
                HStack {
                    Text("최고 연속 \(streak.best)일")
                    Spacer()
                    if streak.atRiskToday {
                        Text("오늘 아직 0그루").foregroundStyle(Color(hex: "#C0562F"))
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    // MARK: 기간 이동

    private var periodHeader: some View {
        HStack {
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(periodLabel).font(.subheadline.weight(.medium))
            Spacer()
            Button { shift(1) } label: { Image(systemName: "chevron.right") }
                .disabled(isAtPresent)
        }
        .padding(.horizontal, 24)
    }

    private var periodLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        switch scope {
        case .day:   f.dateFormat = "M월 d일 (E)"
        case .week:  f.dateFormat = "M월 d일"
            let end = Calendar.current.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            return "\(f.string(from: weekStart)) ~ \(f.string(from: end))"
        case .month: f.dateFormat = "yyyy년 M월"
        case .year:  f.dateFormat = "yyyy년"
        }
        return f.string(from: anchor)
    }

    private var isAtPresent: Bool {
        let cal = Calendar.current
        switch scope {
        case .day:   return cal.isDate(anchor, inSameDayAs: GardenStats.today)
        case .week:  return weekStart >= currentWeekStart
        case .month: return cal.isDate(anchor, equalTo: Date(), toGranularity: .month)
        case .year:  return cal.isDate(anchor, equalTo: Date(), toGranularity: .year)
        }
    }

    private func shift(_ n: Int) {
        let cal = Calendar.current
        let unit: Calendar.Component = {
            switch scope {
            case .day: return .day
            case .week: return .weekOfYear
            case .month: return .month
            case .year: return .year
            }
        }()
        if let moved = cal.date(byAdding: unit, value: n, to: anchor) { anchor = moved }
    }

    // MARK: 뷰들

    private var dayView: some View {
        let day = garden[GardenStats.dayStart(of: anchor)]
            ?? DayGarden(date: GardenStats.dayStart(of: anchor), plants: [], moss: 0)
        return VStack(spacing: 12) {
            DayPotView(day: day)
                .frame(height: 220)
                .padding(.horizontal, 40)
            if day.isEmpty {
                Text("이 날은 아직 비어 있어요").font(.footnote).foregroundStyle(.secondary)
            } else {
                Text(summaryText(day)).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var weekStart: Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: anchor)
        return GardenStats.dayStart(of: cal.date(from: comps) ?? anchor)
    }
    private var currentWeekStart: Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return GardenStats.dayStart(of: cal.date(from: comps) ?? Date())
    }

    private var weekView: some View {
        let cal = Calendar.current
        let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
        return HStack(spacing: 6) {
            ForEach(days, id: \.self) { d in
                let key = GardenStats.dayStart(of: d)
                VStack(spacing: 4) {
                    DayPotView(day: garden[key] ?? DayGarden(date: key, plants: [], moss: 0))
                        .frame(height: 96)
                    Text(shortWeekday(d)).font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var monthView: some View {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: anchor)
        let first = cal.date(from: comps) ?? anchor
        let count = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        let days = (0..<count).compactMap { cal.date(byAdding: .day, value: $0, to: first) }
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 5) {
            ForEach(days, id: \.self) { d in
                let key = GardenStats.dayStart(of: d)
                DayPotView(day: garden[key] ?? DayGarden(date: key, plants: [], moss: 0), showsPot: false)
                    .aspectRatio(1, contentMode: .fit)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
        }
    }

    /// 연간은 식물 대신 색 농도 — 365칸에서는 어차피 식물이 안 보이고 성능만 나빠진다
    private var yearView: some View {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year], from: anchor)
        let first = cal.date(from: comps) ?? anchor
        let count = cal.range(of: .day, in: .year, for: first)?.count ?? 365
        let days = (0..<count).compactMap { cal.date(byAdding: .day, value: $0, to: first) }
        let total = days.reduce(0) { $0 + (garden[GardenStats.dayStart(of: $1)]?.count ?? 0) }

        return VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 14), spacing: 3) {
                ForEach(days, id: \.self) { d in
                    let n = garden[GardenStats.dayStart(of: d)]?.count ?? 0
                    RoundedRectangle(cornerRadius: 2)
                        .fill(densityColor(n))
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            HStack(spacing: 6) {
                Text("올해 \(total)그루").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("적음").font(.caption2).foregroundStyle(.secondary)
                ForEach(0..<5) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(densityColor(i == 0 ? 0 : i * 2))
                        .frame(width: 10, height: 10)
                }
                Text("많음").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func densityColor(_ n: Int) -> Color {
        switch n {
        case 0:     return Color.secondary.opacity(0.12)
        case 1:     return Color(hex: "#C7E3AE")
        case 2...3: return Color(hex: "#98CE74")
        case 4...5: return Color(hex: "#5FAA47")
        default:    return Color(hex: "#2F7F5B")
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            ForEach(PlantKind.allCases, id: \.self) { k in
                HStack(spacing: 4) {
                    Circle().fill(k.mainColor).frame(width: 8, height: 8)
                    Text(k.label).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 4)
    }

    private func summaryText(_ day: DayGarden) -> String {
        var parts: [String] = []
        for kind in PlantKind.allCases.reversed() {
            let n = day.plants.filter { $0 == kind }.count
            if n > 0 { parts.append("\(kind.label) \(n)") }
        }
        if day.moss > 0 { parts.append("이끼 \(day.moss)") }
        if day.hasRarePlant { parts.append("✨희귀종") }
        return parts.joined(separator: " · ")
    }

    private func shortWeekday(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "E"
        return f.string(from: d)
    }
}
