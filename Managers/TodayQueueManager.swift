//
//  TodayQueueManager.swift
//  JjingToDo
//
//  Created by Jeongah Seo on 4/21/25.
//

// JjingToDo – resets "오늘 할 일" 큐 매일 02:00 KST, and doubles points when completed before expiry.
// ------------------------------------------------------
// 1. Add `bonusGranted` (Bool) to TaskEntity in CoreData ➜ Lightweight migration
// 2. Grant 2× points when: task.isToday == true && finished before todayExpires && bonusGranted == false
// 3. BGTaskScheduler schedules reset (~02:05) and clears expired Today flags.
// 4. ScenePhase .active triggers quick reset check when app foregrounds.
// ------------------------------------------------------

import Foundation
import BackgroundTasks
import CoreData
import SwiftUI

final class TodayQueueManager {
    static let shared = TodayQueueManager()
    private let taskIdentifier = "com.fondue.JjingToDo.todayReset"

    private init() {}

    /// Call once in AppDelegate didFinishLaunching
    func registerBGTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            // background thread
            self.handleResetTask(task: task as! BGAppRefreshTask)
        }
    }

    /// Schedule next run (called after each execution as well)
    func scheduleReset() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        // Next 02:05 KST
        if let next = Self.nextResetDate() {
            request.earliestBeginDate = next
            //try? BGTaskScheduler.shared.submit(request)
            do {
                try BGTaskScheduler.shared.submit(request)
                print("✅ BGTask scheduled for", request.earliestBeginDate!)   // ← 이 print
            } catch {
                print("❌ BGTask schedule failed", error)
            }
        }
    }

    private func handleResetTask(task: BGAppRefreshTask) {
        print("🔥🔥🔥 handleResetTask() called at \(Date())")
        
        scheduleReset() // schedule for tomorrow first
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        let op = BlockOperation {
            self.resetExpiredTodayTasks()
            self.resetStreaksIfExpired()    // 20250519 챌린지 streak 리셋
            self.assignRandomTodayTaskIfNeeded()   // 랜덤 Today's Mission 자동 배정
        }
        task.expirationHandler = { queue.cancelAllOperations() }
        op.completionBlock = { task.setTaskCompleted(success: !op.isCancelled) }
        queue.addOperation(op)
    }

    // MARK: - Reset logic

    func resetExpiredTodayTasks(now: Date = Date()) {
        let context = PersistenceController.shared.container.viewContext
        let fetch: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        fetch.predicate = NSPredicate(format: "isToday == YES")
        if let results = try? context.fetch(fetch) {
            for task in results {
                if let expires = task.todayExpires, now >= expires {
                    task.isToday = false
                    task.bonusGranted = false
                    task.isAutoAssigned = false
                    task.todayAssignedAt = nil
                }
            }
            try? context.save()
        }
    }

    // MARK: - Helpers
    /// Next 02:05 local (assumes device time zone KST)
    private static func nextResetDate() -> Date? {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        let now = Date()
        var comp = cal.dateComponents([.year, .month, .day], from: now)
        comp.hour = 2
        comp.minute = 5
        comp.second = 0
        var target = cal.date(from: comp)!
        if target <= now { target = cal.date(byAdding: .day, value: 1, to: target)! }
        return target
    }
    
    /// 아래 부분은 나중에 필요에 따라 분리할 것
    /// resetStreaksIfExpired
    /// fetchAllChallenges
    // 20250519 챌린지 streak 리셋용
    // MARK: - Streak Reset (챌린지 연속 실패 감지)
    private func resetStreaksIfExpired() {
        let context = PersistenceController.shared.container.viewContext
        let challenges = fetchAllChallenges()

        for challenge in challenges {
            if let last = challenge.lastCompletedAt {
                let gap = Date.adjustedNowBy2AM.daysSinceBy2AM(from: last)
                if gap >= 2 {
                    challenge.streakCount = 0
                    print("🔁 streak 리셋: \(challenge.title ?? "무제") gap = \(gap)")
                }
            }
        }

        do {
            try context.save()
        } catch {
            print("⚠️ streak 리셋 저장 실패: \(error)")
        }
    }

    // MARK: - Random Today's Mission 자동 배정
    /// BGTask + 포그라운드 진입 양쪽에서 안전하게 호출 가능
    /// - 이미 오늘 자동배정 항목이 있으면 스킵 (중복 방지)
    /// - 02:00 이전이면 스킵
    func assignRandomTodayTaskIfNeeded() {
        let context = PersistenceController.shared.container.viewContext
        let cal = Calendar.current
        let now = Date()

        // 02:00 이전이면 스킵
        let today2AM = cal.date(byAdding: .hour, value: 2, to: cal.startOfDay(for: now))!
        guard now >= today2AM else {
            print("🎲 배정 스킵: 02:00 이전")
            return
        }

        // 이미 오늘 자동배정된 항목이 있으면 스킵
        let checkFetch: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        checkFetch.predicate = NSPredicate(format: "isAutoAssigned == YES AND isToday == YES")
        if let existing = try? context.fetch(checkFetch), !existing.isEmpty {
            print("🎲 배정 스킵: 이미 배정된 항목 있음")
            return
        }

        let fetch: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        fetch.predicate = NSPredicate(format: "isCompleted == NO AND isToday == NO")
        guard let tasks = try? context.fetch(fetch), let picked = tasks.randomElement() else { return }

        picked.isToday = true
        picked.isAutoAssigned = true
        picked.todayAssignedAt = now
        try? context.save()
        print("🎲 랜덤 Today's Mission 배정: \(picked.title ?? "무제")")
    }

    /// 앱 포그라운드 진입 시 호출 — 만료 정리 후 미배정이면 랜덤 배정
    func performForegroundCheck() {
        resetExpiredTodayTasks()
        assignRandomTodayTaskIfNeeded()
    }

    private func fetchAllChallenges() -> [ChallengeEntity] {
        let request: NSFetchRequest<ChallengeEntity> = ChallengeEntity.fetchRequest()
        request.sortDescriptors = []
        do {
            return try PersistenceController.shared.container.viewContext.fetch(request)
        } catch {
            print("⚠️ 챌린지 가져오기 실패: \(error)")
            return []
        }
    }
}

// MARK: - TaskEntity helper (put in TaskEntity+Today.swift)
extension TaskEntity {
    var todayExpires: Date? {
        guard let assigned = todayAssignedAt else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: assigned)
        return calendar.date(byAdding: DateComponents(day: 1, hour: 2), to: start)
    }
}



