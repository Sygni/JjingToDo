//
//  UserEntity+CoreDataProperties.swift
//  JjingToDo
//
//  Created by Jeongah Seo on 3/28/25.
//

import Foundation
import CoreData
import SwiftUI

extension UserEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserEntity> {
        return NSFetchRequest<UserEntity>(entityName: "UserEntity")
    }

    @NSManaged public var id: UUID
    @NSManaged public var points: Int32
    @NSManaged public var joinedAt: Date
    @NSManaged public var lifetimePoints: Int64
    
    // Add this as an override to ensure SwiftUI detects changes
    public var pointsPublisher: Binding<Int32> {
        Binding(
            get: { self.points },
            set: { newValue in
                self.points = newValue
            }
        )
    }
}
