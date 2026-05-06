//
//  MainTodoView+Today.swift.swift
//  JjingToDo
//
//  Created by Jeongah Seo on 4/20/25.
//

import Foundation
import CoreData

extension MainTodoView {
    /// 오늘 할 일만 필터링 — 자동배정(🎲) 항목을 맨 위에 고정
    var todayTasks: [TaskEntity] {
        taskEntities
            .filter { $0.isToday && !$0.isCompleted }
            .sorted {
                if $0.isAutoAssigned != $1.isAutoAssigned { return $0.isAutoAssigned }
                return $0.taskType.rawValue < $1.taskType.rawValue
            }
    }

    /// 나머지(일반) 태스크
    var otherTasks: [TaskEntity] {
        var base = sortedTaskEntities.filter { !$0.isToday }

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
            // 시간 제한 해제 중 (재활성화 시 아래 주석 풀기)
            // guard now >= earliest && now < latest else {
            //     todayLimitMessage = "매일 02:00 ~ 12:00 사이에만 지정 가능!"
            //     showTodayLimitAlert = true
            //     return
            // }

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
