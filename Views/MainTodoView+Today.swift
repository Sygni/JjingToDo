//
//  MainTodoView+Today.swift.swift
//  JjingToDo
//
//  Created by Jeongah Seo on 4/20/25.
//

import Foundation
import CoreData

extension MainTodoView {
    /// 오늘 할 일만 필터링
    var todayTasks: [TaskEntity] {
        taskEntities
            .filter { $0.isToday && !$0.isCompleted }
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    /// 나머지(일반) 태스크
    /// 20250423 투두리스트에 타입 필터 추가
    var otherTasks: [TaskEntity] {
        let base = sortedTaskEntities.filter { !$0.isToday }

        if let selected = selectedFilterType {
            return base.filter { $0.taskType == selected }
        } else {
            return base
        }
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
            // ✅ 오늘 할 일 등록 조건: 02:00 ≤ now < 12:00
            guard now >= earliest && now < latest else {
                todayLimitMessage = "매일 02:00 ~ 12:00 사이에만 지정 가능!"
                showTodayLimitAlert = true
                return
            }

            task.isToday = true
            task.todayAssignedAt = now
        } else {
            // ⛔️ 해제는 언제든지 가능
            task.isToday = false
            task.todayAssignedAt = nil
        }

        try? viewContext.save()
    }
}
