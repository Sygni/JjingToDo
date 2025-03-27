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
        container = NSPersistentContainer(name: "DataModel") // ← .xcdatamodeld 파일 이름!
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data 로드 실패: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
