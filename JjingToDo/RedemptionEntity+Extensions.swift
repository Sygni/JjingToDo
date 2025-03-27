//
//  RedemptionEntity+Extensions.swift
//  JjingToDo
//
//  Created by Jeongah Seo on 3/27/25.
//

import Foundation
import CoreData

extension RedemptionEntity: Identifiable {
    var formattedDate: String {
        createdAt?.formatted(date: .abbreviated, time: .shortened) ?? ""
    }
}
