//
//  Untitled.swift
//  JjingToDo
//
//  Created by Jeongah Seo on 3/29/25.
//

import SwiftUI
import CoreData

struct DebugToolView: View {
    @Binding var refreshTrigger: UUID   // 20250328 Debug View 리프레시용
    
    @Environment(\..managedObjectContext) private var viewContext
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("💣 전체 리셋")) {
                    Button("모든 데이터 삭제") {
                        resetAllData()
                        refreshTrigger = UUID() // 트리거 변경 → 뷰 리렌더링
                    }
                    .foregroundColor(.red)
                }

                Section(header: Text("🧪 테스트용 설정")) {
                    Button("포인트 10000으로 설정") {
                        setPoints(to: 10000)
                        refreshTrigger = UUID() // 트리거 변경 → 뷰 리렌더링
                    }

                    Button("보상 더미 추가") {
                        addDummyReward()
                        refreshTrigger = UUID() // 트리거 변경 → 뷰 리렌더링
                    }

                    Button("태스크 전체 삭제") {
                        deleteAllTasks()
                        refreshTrigger = UUID() // 트리거 변경 → 뷰 리렌더링
                    }
                }
            }
            .navigationTitle("디버그 툴")
        }
    }

    private func resetAllData() {
        // 1. UserEntity 삭제
        let userFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "UserEntity")
        let userDelete = NSBatchDeleteRequest(fetchRequest: userFetch)
        try? viewContext.execute(userDelete)

        // 2. TaskEntity 삭제 (직접 삭제)
        let taskFetch: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        if let tasks = try? viewContext.fetch(taskFetch) {
            for task in tasks {
                viewContext.delete(task)
            }
        }

        // 3. RewardEntity 삭제 (직접 삭제)
        let rewardFetch: NSFetchRequest<RewardEntity> = RewardEntity.fetchRequest()
        if let rewards = try? viewContext.fetch(rewardFetch) {
            for reward in rewards {
                viewContext.delete(reward)
            }
        }

        // 4. 유저 재생성 + 포인트 초기화
        let newUser = UserEntity(context: viewContext)
        newUser.id = UUID()
        newUser.points = 0
        newUser.joinedAt = Date()

        // 5. 저장 및 refresh
        try? viewContext.save()
        viewContext.refreshAllObjects()
        
        print("✅ 전체 데이터 삭제 + 포인트 초기화 + 보상 삭제 완료")
    }

    private func setPoints(to amount: Int32) {
        let request = UserEntity.fetchRequest()
        if let user = try? viewContext.fetch(request).first {
            user.points = amount
            try? viewContext.save()
            print("✅ 포인트 설정 완료")
        }
    }

    private func addDummyReward() {
        let reward = RewardEntity(context: viewContext)
        reward.id = UUID()
        reward.title = "테스트 보상"
        reward.pointCost = 100
        reward.remainingCount = 3
        reward.createdAt = Date()
        reward.rewardType = "기타"
        try? viewContext.save()
        print("✅ 더미 보상 추가 완료")
    }

    private func deleteAllTasks() {
        viewContext.refreshAllObjects()
        
        let fetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        do {
            let tasks = try viewContext.fetch(fetchRequest)
            for task in tasks {
                viewContext.delete(task)
            }
            try viewContext.save()
            print("✅ 직접 태스크 삭제 완료")
        } catch {
            print("❌ 직접 삭제 실패: \(error.localizedDescription)")
        }

        debugCheckTaskCount()
    }
    
    private func debugCheckTaskCount() {
        let fetchRequest = NSFetchRequest<TaskEntity>(entityName: "TaskEntity")
        do {
            let tasks = try viewContext.fetch(fetchRequest)
            print("🧪 남아있는 태스크 수: \(tasks.count)")
        } catch {
            print("❌ 태스크 fetch 실패: \(error.localizedDescription)")
        }
    }
}

#if DEBUG
struct DebugToolView_Previews: PreviewProvider {
    static var previews: some View {
        DebugToolView(refreshTrigger: .constant(UUID())).environment(\..managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
#endif
