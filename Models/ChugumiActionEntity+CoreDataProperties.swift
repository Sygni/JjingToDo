//
//  ChugumiActionEntity+CoreDataProperties.swift
//  JjingToDo
//
//  Created by Jeongah Seo on 4/21/25.
//
//

import Foundation
import CoreData


extension ChugumiActionEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChugumiActionEntity> {
        return NSFetchRequest<ChugumiActionEntity>(entityName: "ChugumiActionEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var memo: String?
    @NSManaged public var point: Int32
    @NSManaged public var timestamp: Date?
    @NSManaged public var type: String?

}

extension ChugumiActionEntity : Identifiable {

}
