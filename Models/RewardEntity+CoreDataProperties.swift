//
//  RewardEntity+CoreDataProperties.swift
//  JjingToDo
//

import Foundation
import CoreData

extension RewardEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<RewardEntity> {
        return NSFetchRequest<RewardEntity>(entityName: "RewardEntity")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var pointCost: Int32
    @NSManaged public var remainingCount: Int32
    @NSManaged public var rewardType: String?
    @NSManaged public var sortOrder: Int32
    @NSManaged public var title: String?

}

extension RewardEntity: Identifiable {
}
