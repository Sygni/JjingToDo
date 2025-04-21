//
//  ChugumiManager.swift
//  JjingToDo
//
//  Created by Jeongah Seo on 4/21/25.
//

import CoreData

class ChugumiManager {
    static let shared = ChugumiManager()
    private let context = PersistenceController.shared.container.viewContext

    func addChugumiAction(type: String, memo: String?) {
        let newAction = ChugumiActionEntity(context: context)
        newAction.id = UUID()
        newAction.timestamp = Date()
        newAction.type = type
        newAction.memo = memo
        newAction.point = 160

        // 유저 포인트 증가
        if let user = fetchUser() {
            user.points += 160
        }

        do {
            try context.save()
            print("✅ 추구미 액션 저장 완료")
        } catch {
            print("❌ 추구미 액션 저장 실패: \(error.localizedDescription)")
        }
    }

    private func fetchUser() -> UserEntity? {
        let request: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first
    }
}
