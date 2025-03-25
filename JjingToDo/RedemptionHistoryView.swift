//
//  RedemptionHistoryView.swift
//  HelloSwiftUI
//
//  Created by Jeongah Seo on 3/24/25.
//
import SwiftUI

struct RedemptionHistoryView: View {
    // 저장된 기록 불러오기
    //@State private var redemptions: [Redemption] = []
    @Binding var tasks: [Task]
    @Binding var redemptions: [Redemption]
    
    let redemptionKey = "savedRedemptions"

    var body: some View {
        NavigationView {
            let sortedRedemptions = redemptions.sorted {
                if $0.isUsed == $1.isUsed {
                    return $0.date > $1.date  // 같은 사용 상태일 땐 최근 순
                } else {
                    return !$0.isUsed  // 미사용이 먼저
                }
            }
            
            List(sortedRedemptions) { redemption in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("💸 \(redemption.amount)원 쿠폰")
                            .font(.headline)
                        Text(redemption.isUsed ? "☑️ 사용 완료" : "🏆 미사용")
                            .font(.caption)
                            .foregroundColor(redemption.isUsed ? .gray : .orange)
                        Text(redemption.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()  // 우측 밀어주기

                    if !redemption.isUsed {
                        Button(action: {
                            markRedemptionUsed(redemption)
                        }) {
                            Text("사용")
                                .font(.subheadline)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(hex: "#79e5cb"))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        /*
        .onAppear {
            loadRedemptions()
        }
        */
    }

    func loadRedemptions() {
        if let savedRedemptions = UserDefaults.standard.data(forKey: "savedRedemptions"),
           let decoded = try? JSONDecoder().decode([Redemption].self, from: savedRedemptions) {
            redemptions = decoded
        }
    }
    
    func markRedemptionUsed(_ redemption: Redemption) {
        if let i = redemptions.firstIndex(where: { $0.id == redemption.id }) {
            redemptions[i].isUsed = true
            saveData(tasks: tasks, redemptions: redemptions)
        }
    }
}

