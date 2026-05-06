//
//  ChallengeListInTabView.swift
//  JjingToDo
//
//  Created by Jeongah Seo on 4/29/25.
//

import SwiftUI

struct ChallengeListInTabView: View {
    @ObservedObject var viewModel: ChallengeViewModel
    
    var body: some View {
        List {
            ForEach(viewModel.challenges) { challenge in
                ChallengeRowInTabView(challenge: challenge, completeAction: {
                    viewModel.completeChallenge(challenge)
                })
                //.listRowSeparator(.hidden)
                .listRowInsets(.init(top: -2, leading: -4, bottom: -2, trailing: -4))
                // ✅ 셀 기본 배경 직접 지정
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 0)
                        .fill(
                            challenge.isMorningChallenge && Date().isMorningBy2AM
                            ? Color.yellow.opacity(0.18)       // 파스텔 노랑
                            : Color(.clear)
                        )
                )
            }
        }
        .listStyle(.plain)
        //.listRowSpacing(4)
        .background(Color.clear)
        .onAppear {
            UITableViewCell.appearance().backgroundColor = .clear   // 계층 제거
        }
    }
}

struct ChallengeRowInTabView: View {
    @ObservedObject var challenge: ChallengeEntity
    var completeAction: () -> Void
    
    var body: some View {
        
        let isMorning = challenge.isMorningChallenge
        let days = daysSinceOptionalBy2AM(challenge.lastCompletedAt) ?? -1
        
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.title ?? "Untitled")
                    .font(.headline)
                
                HStack(spacing: 10) {
                    Text("이번 주 \(max(0, challenge.weeklyCount))회")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#79e5cb"))
                    Text("연속 \(max(0, challenge.streakCount))일째")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#79e5cb"))
                    Text("+\(max(0, challenge.rewardPoint))점")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#79e5cb"))
                }
            }
            
            Spacer()
            
            if isMorning {
                Text("☀️")
            }
            
            //최근 마지막으로 한 날짜로부터 얼마나 경과했나 보여주기
            if days == -1 {
                Text("—")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            } else if days == 0 {       // 수행한 당일
                Text("💎")
                    .foregroundColor(statusColor(for: days))
            } else {
                Text("+\(days)")
                    .font(.caption)
                    .foregroundColor(statusColor(for: days))
            }
            
            // 할 때마다 누를 수 있도록 버튼은 언제나 활성화
            Button(action: {
                completeAction()
                
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }) {
                Text("🙌")
                    .font(.title)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color(hex: "#79e5cb").opacity(0.20))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // 아침 모드 - 설정된 항목은 오전에 수행하면 포인트 2배
            Button {
                challenge.isMorningChallenge.toggle()
                try? challenge.managedObjectContext?.save()
                print("isMorningChallenge: ", challenge.isMorningChallenge)
            } label: {
                Label(
                    challenge.isMorningChallenge ? "아침 해제" : "아침 설정",
                    systemImage: "sunrise.fill"
                )
            }
            .tint(challenge.isMorningChallenge ? .gray : .orange)
            
            // 🗑️ 삭제
            Button(role: .destructive) {
                if let context = challenge.managedObjectContext {
                    context.delete(challenge)
                    try? context.save()
                }
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
        .onAppear {
            print("📅 days: \(days), lastCompletedAt: \(String(describing: challenge.lastCompletedAt))")
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
        let diff = Calendar.current.dateComponents([.day], from: date, to: Date()).day
        return diff ?? nil
    }

    func daysSinceOptionalBy2AM(_ date: Date?) -> Int? {
        guard let date else { return nil }
        return Date.adjustedNowBy2AM.daysSinceBy2AM(from: date)   // ← 반드시 adjustedNowBy2AM
    }
}

