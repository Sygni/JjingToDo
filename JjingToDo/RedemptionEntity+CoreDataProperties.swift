//
//  RedemptionEntity+CoreDataProperties.swift
//  JjingToDo
//
//  Created by Jeongah Seo on 3/27/25.
//

import Foundation
import CoreData

extension RedemptionEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<RedemptionEntity> {
        return NSFetchRequest<RedemptionEntity>(entityName: "RedemptionEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var amount: Int64
    @NSManaged public var createdAt: Date?
    @NSManaged public var isUsed: Bool
}
