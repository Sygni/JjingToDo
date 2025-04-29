//
//  ChallengeEntity+CoreDataProperties.swift
//  JjingToDo
//
//  Created by Jeongah Seo on 4/29/25.
//
//

import Foundation
import CoreData


extension ChallengeEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChallengeEntity> {
        return NSFetchRequest<ChallengeEntity>(entityName: "ChallengeEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var challengeType: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var lastCompletedAt: Date?
    @NSManaged public var streakCount: Int32
    @NSManaged public var totalCount: Int32
    @NSManaged public var rewardPoint: Int32
    @NSManaged public var frequencyCount: Int32

}

extension ChallengeEntity : Identifiable {

}
