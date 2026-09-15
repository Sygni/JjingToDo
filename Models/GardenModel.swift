//
//  GardenModel.swift
//  JjingToDo
//
//  정원 = 완료 기록의 시각화.
//  새 CoreData 필드 없이 completedAt / rewardLevelRaw / ChugumiActionEntity.timestamp에서 계산한다.
//  (저장하지 않으므로 값이 어긋날 일이 없고 CSV 백업에도 자동으로 보존된다)
//

import Foundation
import SwiftUI
import CoreData
import WidgetKit

// MARK: - 앱 전용 연결
// PlantKind·DayGarden 같은 순수 정원 타입은 위젯과 함께 쓰려고 GardenCore.swift로 옮겼다.
// RewardLevel은 앱 전용 모델이라 이 연결만 여기에 남긴다.

extension PlantKind {
    init(reward: RewardLevel) {
        self = PlantKind(rawValue: reward.rawValue) ?? .sprout
    }
}

// MARK: - 등급

/// 칭호 + 단계. 단계는 무한히 올라가고 칭호는 구간마다 바뀐다.
struct GardenRank {
    let stage: Int          // 1부터 무한
    let title: String
    let planted: Int        // 누적 심은 식물 수 (= 완료한 할 일 수)
    let currentBase: Int    // 이번 단계 시작 개수
    let nextRequired: Int   // 다음 단계에 필요한 개수

    var remaining: Int { max(0, nextRequired - planted) }
    var progress: Double {
        let span = max(1, nextRequired - currentBase)
        return min(1, max(0, Double(planted - currentBase) / Double(span)))
    }

    /// 단계별 누적 필요량 — 완만한 지수 곡선이라 계속 올라간다
    static func requirement(forStage stage: Int) -> Int {
        guard stage > 1 else { return 0 }
        let n = Double(stage - 1)
        return Int((6 * pow(n, 1.45)).rounded())
    }

    /// 칭호는 정원의 규모로 — 바닥나면 마지막 칭호가 유지되고 단계만 올라간다
    static let titles: [(minStage: Int, name: String)] = [
        (1, "씨앗"), (3, "새싹"), (6, "화분"), (10, "화단"), (15, "텃밭"),
        (21, "뜰"), (28, "정원"), (36, "온실"), (45, "수목원"), (55, "숲")
    ]

    static func title(forStage stage: Int) -> String {
        titles.last { stage >= $0.minStage }?.name ?? "씨앗"
    }

    /// 단계가 올라가는 지점들 (몇 번째 식물이 승급을 시켰는지 판별용)
    static func stageThresholds(upTo total: Int) -> Set<Int> {
        var result = Set<Int>()
        var stage = 2
        while stage < 999 {
            let need = requirement(forStage: stage)
            if need > total { break }
            if need > 0 { result.insert(need) }
            stage += 1
        }
        return result
    }

    static func make(planted: Int) -> GardenRank {
        var stage = 1
        while requirement(forStage: stage + 1) <= planted, stage < 999 { stage += 1 }
        return GardenRank(stage: stage,
                          title: title(forStage: stage),
                          planted: planted,
                          currentBase: requirement(forStage: stage),
                          nextRequired: requirement(forStage: stage + 1))
    }
}

// MARK: - 연속

struct StreakInfo {
    var current: Int = 0
    var best: Int = 0
    /// 오늘 아직 아무것도 안 해서 연속이 끊길 위험
    var atRiskToday: Bool = false
}

// MARK: - 집계

enum GardenStats {

    /// 정원을 시작한 날. 이전 기록은 세지 않는다.
    /// 완료 기록 자체는 지우지 않으므로 언제든 되돌릴 수 있다.
    static let startDateKey = "gardenStartDate"

    static var startDate: Date? {
        let t = UserDefaults.standard.double(forKey: startDateKey)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    /// 오늘부터 다시 시작
    static func resetStart(to date: Date = Date()) {
        UserDefaults.standard.set(dayStart(of: date).timeIntervalSince1970, forKey: startDateKey)
    }

    static func clearStart() {
        UserDefaults.standard.removeObject(forKey: startDateKey)
    }

    private static func isCounted(_ date: Date) -> Bool {
        guard let start = startDate else { return true }
        return dayStart(of: date) >= dayStart(of: start)
    }

    /// 02:00 기준으로 맞춘 "그날"의 시작 시각 (위젯과 같은 계산을 쓰도록 GardenCalendar에 위임)
    static func dayStart(of date: Date) -> Date {
        GardenCalendar.dayStart(of: date)
    }

    static var today: Date { dayStart(of: Date()) }

    /// 완료한 할 일 + 추구미 액션을 날짜별로 묶는다
    static func build(tasks: [TaskEntity], moss: [ChugumiActionEntity]) -> [Date: DayGarden] {
        var map: [Date: DayGarden] = [:]

        // 완료 순서대로 번호를 매겨야 몇 번째 식물이 등급을 올렸는지 알 수 있다
        let done = tasks.compactMap { task -> (Date, PlantKind)? in
            guard task.isCompleted, let at = task.completedAt, isCounted(at) else { return nil }
            return (at, PlantKind(reward: RewardLevel(rawValue: Int(task.rewardLevelRaw)) ?? .easy))
        }.sorted { $0.0 < $1.0 }

        let milestones = GardenRank.stageThresholds(upTo: done.count)

        for (i, entry) in done.enumerated() {
            let day = dayStart(of: entry.0)
            let item = PlantedItem(kind: entry.1, isLevelUp: milestones.contains(i + 1))
            map[day, default: DayGarden(date: day, plants: [], moss: 0)].plants.append(item)
        }

        for action in moss {
            guard let ts = action.timestamp, isCounted(ts) else { continue }
            let day = dayStart(of: ts)
            map[day, default: DayGarden(date: day, plants: [], moss: 0)].moss += 1
        }

        // 각 날짜까지의 연속 일수를 채워 넣는다 (희귀종 판정용)
        let planted = map.filter { !$0.value.plants.isEmpty }.keys.sorted()
        var run = 0
        var previous: Date? = nil
        for day in planted {
            if let prev = previous, Calendar.current.dateComponents([.day], from: prev, to: day).day == 1 {
                run += 1
            } else {
                run = 1
            }
            map[day]?.streakAtDay = run
            previous = day
        }
        return map
    }

    // MARK: 위젯

    /// 이번 주 정원을 App Group에 넘기고 위젯을 새로 그리게 한다.
    /// 위젯은 Core Data를 열지 않고 이 요약만 읽는다.
    static func publishWidgetSnapshot(context: NSManagedObjectContext) {
        let taskRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        let mossRequest: NSFetchRequest<ChugumiActionEntity> = ChugumiActionEntity.fetchRequest()
        let tasks = (try? context.fetch(taskRequest)) ?? []
        let moss = (try? context.fetch(mossRequest)) ?? []
        let map = build(tasks: tasks, moss: moss)

        let start = GardenCalendar.weekStart(containing: Date())
        let gardens = GardenCalendar.weekDays(from: start).map { day in
            map[day] ?? DayGarden(date: day, plants: [], moss: 0)
        }
        GardenSnapshot(weekStart: start, gardens: gardens).save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 누적 심은 식물 수 = 완료한 할 일 수
    static func plantedCount(tasks: [TaskEntity]) -> Int {
        tasks.filter { task in
            guard task.isCompleted, let done = task.completedAt else { return false }
            return isCounted(done)
        }.count
    }

    /// 연속 일수 — 하루에 하나라도 완료하면 유지. 02:00 기준.
    static func streak(tasks: [TaskEntity]) -> StreakInfo {
        let days = Set(tasks.compactMap { task -> Date? in
            guard task.isCompleted, let done = task.completedAt, isCounted(done) else { return nil }
            return dayStart(of: done)
        }).sorted()

        guard !days.isEmpty else { return StreakInfo() }

        var best = 1, run = 1
        for i in 1..<max(1, days.count) {
            let gap = Calendar.current.dateComponents([.day], from: days[i - 1], to: days[i]).day ?? 0
            run = (gap == 1) ? run + 1 : 1
            best = max(best, run)
        }

        // 현재 연속: 오늘 또는 어제까지 이어져 있어야 살아 있다
        let todayStart = today
        let cal = Calendar.current
        var current = 0
        if let last = days.last {
            let sinceLast = cal.dateComponents([.day], from: last, to: todayStart).day ?? 99
            if sinceLast <= 1 {
                current = 1
                var cursor = last
                for day in days.dropLast().reversed() {
                    if cal.dateComponents([.day], from: day, to: cursor).day == 1 {
                        current += 1
                        cursor = day
                    } else { break }
                }
            }
        }
        let didToday = days.contains(todayStart)
        return StreakInfo(current: current,
                          best: max(best, current),
                          atRiskToday: current > 0 && !didToday)
    }
}
