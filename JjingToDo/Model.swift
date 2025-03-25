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

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false, createdAt: Date = Date(), completedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

struct Redemption: Identifiable, Codable {
    let id: UUID
    let amount: Int       // 예: 5000, 10000
    let date: Date        // 환전한 날짜/시간
}
