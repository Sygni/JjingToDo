//
//  MainTodoView+Today.swift.swift
//  JjingToDo
//
//  Created by Jeongah Seo on 4/20/25.
//

import Foundation
import CoreData

extension MainTodoView {

    /// dueDate가 오늘인지 여부
    func isDueToday(_ task: TaskEntity) -> Bool {
        guard let due = task.dueDate else { return false }
        return Calendar.current.isDateInToday(due)
    }

    /// 오늘 할 일 — 자동배정 → 마감오늘 → 수동등록 순
    var todayTasks: [TaskEntity] {
        taskEntities
            .filter { !$0.isCompleted && ($0.isToday || isDueToday($0)) }
            .sorted {
                let p0 = todayPriority($0)
                let p1 = todayPriority($1)
                if p0 != p1 { return p0 < p1 }
                // 같은 그룹 내 2차 정렬: 마감일 있으면 빠른 순, 없으면 taskType
                if isDueToday($0) && isDueToday($1) {
                    return ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
                }
                return $0.taskType.rawValue < $1.taskType.rawValue
            }
    }

    /// 0: 자동배정  1: 마감오늘  2: 수동등록
    private func todayPriority(_ task: TaskEntity) -> Int {
        if task.isAutoAssigned { return 0 }
        if isDueToday(task) { return 1 }
        return 2
    }

    /// 나머지(일반) 태스크
    var otherTasks: [TaskEntity] {
        // 완료된 항목은 isToday=true여도 여기에 포함 (데이터 정합성 깨진 경우 복구)
        // 미완료 중 마감오늘 항목은 todayTasks에 표시되므로 제외
        var base = sortedTaskEntities.filter {
            if $0.isCompleted { return true }           // 완료된 건 항상 포함 (isToday=true 복구 포함)
            return !$0.isToday && !isDueToday($0)       // 미완료는 오늘 미션 아닌 것만
        }

        if let selected = selectedFilterType {
            base = base.filter { $0.taskType == selected }
        }

        var incomplete = base.filter { !$0.isCompleted }
        let done = base.filter { $0.isCompleted }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }

        switch questSortOrder {
        case .createdDesc:
            break  // sortedTaskEntities already sorts by createdAt desc
        case .dueDate:
            let withDate = incomplete.filter { $0.dueDate != nil }
                .sorted { ($0.dueDate!) < ($1.dueDate!) }
            let withoutDate = incomplete.filter { $0.dueDate == nil }
            incomplete = withDate + withoutDate
        case .difficulty:
            incomplete = incomplete.sorted { $0.rewardLevelRaw > $1.rewardLevelRaw }
        }

        return incomplete + done
    }

    
    /// 오늘 할 일 토글
    @MainActor
    func toggleToday(_ task: TaskEntity) {
        let now = Date()
        let calendar = Calendar.current

        // 👉 오늘 02:00
        let today = calendar.startOfDay(for: now)
        let earliest = calendar.date(byAdding: DateComponents(hour: 2), to: today)!

        // 👉 오늘 12:00
        let latest = calendar.date(byAdding: DateComponents(hour: 12), to: today)!

        if !task.isToday {
            guard !task.isCompleted else { return }

            task.isToday = true
            task.todayAssignedAt = now
        } else {
            // ⛔️ 해제는 언제든지 가능
            task.isToday = false
            task.isAutoAssigned = false
            task.todayAssignedAt = nil
        }

        try? viewContext.save()
        listRefreshToken += 1
    }
}
