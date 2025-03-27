//
//  TaskEntity+Extensions.swift
//  JjingToDo
//
//  Created by Jeongah Seo on 3/27/25.
//

import Foundation
import CoreData

extension TaskEntity: Identifiable {
    var reward: RewardLevel {
        get { RewardLevel(rawValue: Int(self.rewardLevelRaw)) ?? .easy }
        set { self.rewardLevelRaw = Int16(newValue.rawValue) }
    }

    var safeTitle: String {
        title ?? ""
    }
}

