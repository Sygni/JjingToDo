//
//  TaskEntity+CoreDataProperties.swift
//  JjingToDo
//
//  Created by Jeongah Seo on 4/20/25.
//
//

import Foundation
import CoreData


extension TaskEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TaskEntity> {
        return NSFetchRequest<TaskEntity>(entityName: "TaskEntity")
    }

    @NSManaged public var completedAt: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var difficultyLevel: Int16
    @NSManaged public var id: UUID?
    @NSManaged public var isCompleted: Bool
    @NSManaged public var rewardLevelRaw: Int16
    @NSManaged public var taskTypeRaw: Int16
    @NSManaged public var title: String?
    @NSManaged public var isToday: Bool
    @NSManaged public var todayAssignedAt: Date?
    @NSManaged public var bonusGranted: Bool

}

extension TaskEntity : Identifiable {

}
