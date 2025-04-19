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

    var taskType: TaskType {
        get { TaskType(rawValue: Int(self.taskTypeRaw)) ?? .personal }
        set { self.taskTypeRaw = Int16(newValue.rawValue) }
    }

    var safeTitle: String {
        title ?? ""
    }
}

