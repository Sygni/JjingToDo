//
//  GardenCore.swift
//  JjingToDo
//
//  앱과 위젯이 함께 쓰는 정원 타입.
//  Core Data나 앱 전용 모델(RewardLevel 등)에 기대지 않아야 위젯 타깃에서도 컴파일된다.
//

import Foundation
import SwiftUI

// MARK: - 식물 종류

/// 난이도가 곧 식물 종류 — 어려운 할 일을 해야만 나무가 생긴다
enum PlantKind: Int, CaseIterable {
    case sprout   = 1   // 쉬움
    case flower   = 2   // 보통
    case mushroom = 3   // 어려움
    case tree     = 4   // 매우 어려움

    var label: String {
        switch self {
        case .sprout:   return "새싹"
        case .flower:   return "꽃"
        case .mushroom: return "버섯"
        case .tree:     return "나무"
        }
    }

    /// 정원 색 — 앱 팔레트와 별개로 식물다운 톤
    var mainColor: Color {
        switch self {
        case .sprout:   return Color(hex: "#8FBF4D")
        case .flower:   return Color(hex: "#E88AAE")
        case .mushroom: return Color(hex: "#D4633A")
        case .tree:     return Color(hex: "#3E9B6E")
        }
    }

    /// 난이도 순서대로 키가 커진다 — 새싹이 가장 낮고 나무가 가장 높다
    var heightFactor: CGFloat {
        switch self {
        case .sprout:   return 0.42
        case .flower:   return 0.55
        case .mushroom: return 0.80
        case .tree:     return 1.0
        }
    }

    var subColor: Color {
        switch self {
        case .sprout:   return Color(hex: "#B9D98A")
        case .flower:   return Color(hex: "#F6C3D6")
        case .mushroom: return Color(hex: "#F2D3C4")
        case .tree:     return Color(hex: "#2A7050")
        }
    }
}

// MARK: - 하루치 정원

/// 심긴 식물 한 포기
struct PlantedItem {
    let kind: PlantKind
    /// 이 식물을 심으면서 등급(단계)이 올라갔다 → 황금빛
    var isLevelUp: Bool = false
}

struct DayGarden: Identifiable {
    let date: Date            // 02:00 기준으로 맞춘 그날의 시작
    var plants: [PlantedItem] // 완료한 할 일들
    var moss: Int             // 추구미 액션 수 — 바닥 이끼
    /// 그날까지 이어진 연속 일수 (희귀종 판정용)
    var streakAtDay: Int = 0

    var id: Date { date }
    var isEmpty: Bool { plants.isEmpty && moss == 0 }
    var count: Int { plants.count }

    /// 연속 7일마다 그날 가장 높은 난이도의 식물이 희귀종이 된다
    var hasRarePlant: Bool { streakAtDay > 0 && streakAtDay % 7 == 0 && !plants.isEmpty }
}

// MARK: - 식물 변종과 보여줄 순서

enum PlantVariant {
    case normal
    case rare      // 연속 7일 — 보라빛
    case golden    // 등급 상승 — 황금빛
}

/// 보여줄 순서와 변종이 정해진 한 포기
struct OrderedPlant {
    let item: PlantedItem
    let variant: PlantVariant
    /// 그날 안에서의 순서 — 모양 seed로도 쓰여 화분과 모아심기 화단에서 같은 모양이 나온다
    let index: Int
}

extension DayGarden {
    /// 등급을 올려준 식물과 어려운 것부터. 화분·모아심기 모두 이 규칙을 공유한다.
    func orderedPlants() -> [OrderedPlant] {
        let sorted = plants.sorted {
            if $0.isLevelUp != $1.isLevelUp { return $0.isLevelUp }
            return $0.kind.rawValue > $1.kind.rawValue
        }
        return sorted.enumerated().map { idx, item in
            let variant: PlantVariant = item.isLevelUp ? .golden
                : (hasRarePlant && idx == 0 ? .rare : .normal)
            return OrderedPlant(item: item, variant: variant, index: idx)
        }
    }
}

// MARK: - 날짜 계산

/// 앱과 위젯이 같은 "하루"·"한 주"를 보도록 계산을 한 곳에 둔다
enum GardenCalendar {
    /// 02:00 기준으로 맞춘 "그날"의 시작 시각
    static func dayStart(of date: Date) -> Date {
        let cal = Calendar.current
        let shifted = cal.date(byAdding: .hour, value: -2, to: date) ?? date
        let base = cal.startOfDay(for: shifted)
        return cal.date(byAdding: .hour, value: 2, to: base) ?? base
    }

    /// 그 날이 속한 주의 시작 (02:00 기준)
    static func weekStart(containing date: Date) -> Date {
        let cal = Calendar.current
        // 새벽 1시는 아직 전날이므로, 02:00 기준으로 맞춘 날로 주를 고른다
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: dayStart(of: date))
        let firstMidnight = cal.date(from: comps) ?? date
        // 주 첫날 00:00을 그대로 넣으면 02:00 규칙상 전날로 잡혀 하루 밀린다 — 02:00 이후로 옮긴다
        return dayStart(of: firstMidnight.addingTimeInterval(3 * 3600))
    }

    /// 그 주 7일의 시작 시각들
    static func weekDays(from start: Date) -> [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
            .map { dayStart(of: $0) }
    }
}

// MARK: - 위젯에 넘기는 요약

/// 이번 주 정원 요약. 위젯은 Core Data를 열지 않고 App Group에 저장된 이것만 읽는다.
struct GardenSnapshot: Codable {
    struct Plant: Codable {
        let kind: Int
        let isLevelUp: Bool
    }

    struct Day: Codable {
        let date: Date
        let plants: [Plant]
        let moss: Int
        let streakAtDay: Int
    }

    let weekStart: Date
    let days: [Day]
    let updatedAt: Date

    static let appGroupID = "group.com.fondue.JjingToDo"
    private static let storageKey = "gardenWeekSnapshot"

    init(weekStart: Date, gardens: [DayGarden], updatedAt: Date = Date()) {
        self.weekStart = weekStart
        self.updatedAt = updatedAt
        self.days = gardens.map { garden in
            Day(date: garden.date,
                plants: garden.plants.map { Plant(kind: $0.kind.rawValue, isLevelUp: $0.isLevelUp) },
                moss: garden.moss,
                streakAtDay: garden.streakAtDay)
        }
    }

    var dayGardens: [DayGarden] {
        days.map { day in
            var garden = DayGarden(
                date: day.date,
                plants: day.plants.map {
                    PlantedItem(kind: PlantKind(rawValue: $0.kind) ?? .sprout, isLevelUp: $0.isLevelUp)
                },
                moss: day.moss)
            garden.streakAtDay = day.streakAtDay
            return garden
        }
    }

    func save() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID),
              let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    static func load() -> GardenSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(GardenSnapshot.self, from: data)
    }
}
