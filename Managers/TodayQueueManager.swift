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
                    task.bonusGranted = false   // reset bonus flag for reuse later
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
