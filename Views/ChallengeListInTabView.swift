//
//  ChallengeListInTabView.swift
//  JjingToDo
//
//  Created by Jeongah Seo on 4/29/25.
//

import SwiftUI

struct ChallengeListInTabView: View {
    //@StateObject private var viewModel = ChallengeViewModel()
    @ObservedObject var viewModel: ChallengeViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            /*
             Text("👩‍🎓Jelina🏋️‍♀️")
                .font(.title3)
                .foregroundColor(Color(hex: "#79e5cb"))
                .bold()
                .padding(.leading, 8)
            */
             
            ForEach(viewModel.challenges) { challenge in
                ChallengeRowInTabView(challenge: challenge, completeAction: {
                    viewModel.completeChallenge(challenge)
                })
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                //.shadow(radius: 3)
        )
    }
}

struct ChallengeRowInTabView: View {
    var challenge: ChallengeEntity
    var completeAction: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.title ?? "Untitled")
                    .font(.headline)

                HStack(spacing: 10) {
                    Text("이번 주 \(max(0, challenge.frequencyCount))회")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("연속 \(max(0, challenge.streakCount))일째")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            //최근 마지막으로 한 날짜로부터 얼마나 경과했나 보여주기
            if let days = daysSinceOptional(challenge.lastCompletedAt) {
                if days == 0 {
                    Text("—")
                        .foregroundColor(statusColor(for: days))
                } else {
                    Text("+\(days)")
                        .font(.caption)
                        .foregroundColor(statusColor(for: days))
                }
            } else {
                Text("—") // or 그냥 비워두기
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            // 할 때마다 누를 수 있도록 버튼은 언제나 활성화
            Button(action: completeAction) {
                Text("🙌")
                    .font(.title)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color(hex: "#79e5cb").opacity(0.20))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }

        }
    }
    
    func daysSince(date: Date?) -> Int {
        guard let date = date else { return Int.max }
        return Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? Int.max
    }
    
    func statusColor(for days: Int) -> Color {
        switch days {
        case 0: return .blue
        case 1: return .green
        case 2: return .orange
        default: return .red
        }
    }
    
    func daysSinceOptional(_ date: Date?) -> Int? {
        guard let date else { return nil }
        return Calendar.current.dateComponents([.day], from: date, to: Date()).day
    }
}
