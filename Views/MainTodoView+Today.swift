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

    /// 오늘 할 일 — 아주 중요 → 자동배정 → 마감일있음(빠른순) → 마감일없음 순
    var todayTasks: [TaskEntity] {
        taskEntities
            .filter { !$0.isCompleted && ($0.isToday || isDueToday($0)) }
            .sorted {
                let p0 = todayPriority($0)
                let p1 = todayPriority($1)
                if p0 != p1 { return p0 < p1 }
                // 같은 그룹 안에서는 마감일 빠른 순, 마감일 없는 건 뒤로
                switch ($0.dueDate, $1.dueDate) {
                case let (d0?, d1?): return d0 < d1
                case (.some, .none): return true
                case (.none, .some): return false
                default: return $0.taskType.rawValue < $1.taskType.rawValue
                }
            }
    }

    /// 0: 아주 중요(랜덤 미션보다도 위)  1: 자동배정  2: 마감일 있음  3: 마감일 없음
    private func todayPriority(_ task: TaskEntity) -> Int {
        if task.isImportant { return 0 }
        if task.isAutoAssigned { return 1 }
        if task.dueDate != nil { return 2 }
        return 3
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

        // 아주 중요는 정렬 방식과 상관없이 맨 위 — 각 그룹 안의 순서는 그대로 유지
        incomplete = incomplete.filter { $0.isImportant } + incomplete.filter { !$0.isImportant }

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

    /// 아주 중요 토글
    @MainActor
    func toggleImportant(_ task: TaskEntity) {
        task.isImportant.toggle()
        try? viewContext.save()
        listRefreshToken += 1
    }
}
