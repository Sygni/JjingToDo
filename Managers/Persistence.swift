//
//  Persistence.swift
//  JjingToDo
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "DataModel")

        let description = container.persistentStoreDescriptions.first!

        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // iCloud CloudKit 동기화
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.Fondue.JjingToDo"
            )
            // CloudKit 동기화에 필수: 변경 이력 추적 + 원격 변경 알림
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber,
                                  forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }

        // 자동 마이그레이션
        description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)

        container.loadPersistentStores { _, error in
            if let error {
                // CloudKit 미설정 상태에서도 로컬 저장소는 정상 작동
                print("⚠️ CoreData load error: \(error)")
            }
        }

        // 다른 기기에서 동기화된 변경사항을 viewContext에 자동 반영
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}

extension PersistenceController {
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext

        let exampleTask = TaskEntity(context: viewContext)
        exampleTask.id = UUID()
        exampleTask.title = "미리보기 태스크"
        exampleTask.createdAt = Date()
        exampleTask.isCompleted = false

        try? viewContext.save()
        return controller
    }()
}
