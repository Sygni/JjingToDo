//
//  RedemptionHistoryView.swift
//  HelloSwiftUI
//
//  Created by Jeongah Seo on 3/24/25.
//
import SwiftUI

struct RedemptionHistoryView: View {
    // 저장된 기록 불러오기
    @State private var redemptions: [Redemption] = []

    let redemptionKey = "savedRedemptions"

    var body: some View {
        NavigationView {
            List(redemptions.reversed()) { redemption in
                VStack(alignment: .leading) {
                    Text("💸 \(redemption.amount)포인트 교환")
                    Text(redemption.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("쿠폰 교환 기록")
        }
        .onAppear {
            loadRedemptions()
        }
    }

    func loadRedemptions() {
        if let savedRedemptions = UserDefaults.standard.data(forKey: "savedRedemptions"),
           let decoded = try? JSONDecoder().decode([Redemption].self, from: savedRedemptions) {
            redemptions = decoded
        }
    }
}
