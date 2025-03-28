//
//  AddRewardView.swift
//  JjingToDo
//
//  Created by Jeongah Seo on 3/28/25.
//

import SwiftUI
import CoreData

struct AddRewardView: View {
    @Environment(\.managedObjectContext) var viewContext
    @Binding var showingSheet: Bool
    
    @State private var title = ""
    @State private var pointCost = ""
    @State private var count = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("보상 이름")) {
                    TextField("예: 달달한 커피", text: $title)
                }
                Section(header: Text("필요 포인트")) {
                    TextField("예: 100", text: $pointCost)
                        .keyboardType(.numberPad)
                }
                Section(header: Text("남은 수량")) {
                    TextField("예: 3", text: $count)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("보상 추가")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        showingSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveReward()
                    }
                    .disabled(title.isEmpty || pointCost.isEmpty || count.isEmpty)
                }
            }
        }
    }
    
    private func saveReward() {
        guard !title.isEmpty else {
            print("❌ 제목 없음")
            return
        }

        guard let cost = Int32(pointCost), cost > 0 else {
            print("❌ 포인트 숫자 오류")
            return
        }

        let count = Int32(count) ?? 1
        
        let reward = RewardEntity(context: viewContext)
        reward.id = UUID()
        reward.title = title
        reward.pointCost = cost
        reward.remainingCount = max(1, count)
        reward.createdAt = Date()
        reward.rewardType = "기타"
        
        do {
            try viewContext.save()
            print("🎁 보상 저장 완료!")
            showingSheet = false
        } catch {
            print("❌ 저장 실패: \(error.localizedDescription)")
        }
    }
}
