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

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false, createdAt: Date = Date(), completedAt: Date? = nil, reward: RewardLevel = .easy) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.reward = reward
    }
}

struct Redemption: Identifiable, Codable {
    let id: UUID
    let amount: Int       // 예: 5000, 10000
    let date: Date        // 환전한 날짜/시간
    
    // Used/unused marking
    var isUsed: Bool = false  // ✅ 사용 여부
}

enum RewardLevel: Int, Codable {
    case easy = 1
    case normal = 2
    case hard = 3

    var points: Int {
        switch self {
        case .easy: return 100
        case .normal: return 300
        case .hard: return 500
        }
    }

    var label: String {
        switch self {
        case .easy: return "간단👶"
        case .normal: return "보통🤓"
        case .hard: return "어려움🤯"
        }
    }

    var color: Color {
        switch self {
        case .easy: return .primary
        case .normal: return .mint
        case .hard: return .yellow
        }
    }
}
