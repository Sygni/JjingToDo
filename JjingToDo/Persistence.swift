//
//  Persistence.swift
//  JjingToDo
//
//  Created by Jeongah Seo on 3/27/25.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "DataModel")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
    }
}

extension PersistenceController {
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext

        // 예시: 미리보기용 더미 TaskEntity 생성 가능
        let exampleTask = TaskEntity(context: viewContext)
        exampleTask.id = UUID()
        exampleTask.title = "미리보기 태스크"
        exampleTask.createdAt = Date()
        exampleTask.isCompleted = false

        try? viewContext.save()
        return controller
    }()
}
