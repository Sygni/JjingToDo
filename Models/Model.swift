//
//  Untitled.swift
//  HelloSwiftUI
//
//  Created by Jeongah Seo on 3/24/25.
//

import SwiftUI


struct Task: Identifiable, Hashable, Codable {
    let id: UUID
    let title: String
    var isCompleted: Bool
    let createdAt: Date
    var completedAt: Date?
    
    // Reward system
    var reward: RewardLevel // 1: 쉬움, 2: 보통, 3: 어려움
    var taskType: TaskType // 개인, 공부, 업무

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false, createdAt: Date = Date(), completedAt: Date? = nil, reward: RewardLevel = .easy, taskType: TaskType = .personal) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.reward = reward
        self.taskType = taskType
    }
}

struct Redemption: Identifiable, Codable {
    let id: UUID
    let amount: Int       // 예: 5000, 10000
    let date: Date        // 환전한 날짜/시간
    
    // Used/unused marking
    var isUsed: Bool = false  // ✅ 사용 여부
}

enum RewardLevel: Int, Codable, CaseIterable {
    case easy = 1
    case normal = 2
    case hard = 3
    case veryHard = 4

    var pointValue: Int {
        switch self {
        case .easy: return 100
        case .normal: return 300
        case .hard: return 500
        case .veryHard: return 1000
        }
    }

    var label: String {
        switch self {
        case .easy: return "👶"
        case .normal: return "🤓"
        case .hard: return "🤯"
        case .veryHard: return "🔥"
        }
    }

    var color: Color {
        switch self {
        case .easy: return .primary
        case .normal: return .mint
        case .hard: return .yellow
        case .veryHard: return .red
        }
    }
}

enum TaskType: Int, Codable, CaseIterable {
    case personal = 1
    case study = 2
    case work = 3
    
    var label: String {
        switch self {
        case .personal: return "👸"
        case .study: return "📖"
        case .work: return "💼"
        }
    }
    
    var icon: String {
        switch self {
        case .personal: return "face.smiling.inverse"
        case .study: return "book.pages.fill"
        case .work: return "briefcase.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .personal: return .gray
        case .study: return .gray
        case .work: return .gray
        }
    }

}

enum QuestSortOrder: CaseIterable {
    case createdDesc
    case dueDate
    case difficulty

    var label: String {
        switch self {
        case .createdDesc: return "추가순"
        case .dueDate:     return "마감일순"
        case .difficulty:  return "난이도순"
        }
    }

    var icon: String {
        switch self {
        case .createdDesc: return "clock"
        case .dueDate:     return "calendar"
        case .difficulty:  return "flame"
        }
    }
}
