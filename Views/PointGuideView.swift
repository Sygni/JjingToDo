//
//  PointGuideView.swift
//  JjingToDo
//

import SwiftUI

struct PointGuideView: View {
    var body: some View {
        List {

            // MARK: - 투두 (할 일)
            Section(header: sectionHeader("flag.checkered", "할 일 포인트")) {
                row("👶", "쉬움",       "100 pts")
                row("🤓", "보통",       "300 pts")
                row("🤯", "어려움",     "500 pts")
                row("🔥", "매우 어려움", "1,000 pts")

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.teal)
                        Text("Today's Mission 보너스")
                            .font(.subheadline)
                    }
                    Text("수동 지정 후 만료 전 완료: 포인트 × 2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("🎲 자동 배정(랜덤) 후 만료 전 완료: 포인트 × 3")
                        .font(.caption)
                        .foregroundColor(.teal)
                    Text("매일 02:00 리셋, 당일 12:00까지 지정 가능")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
            }

            // MARK: - 챌린지
            Section(header: sectionHeader("flame.fill", "챌린지 포인트")) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("기본 공식")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    formulaBox("(300 + 누적횟수×2 + 연속일수×10) × 아침배수")
                }
                .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 4) {
                    formulaRow("기본 베이스",    "300 pts")
                    formulaRow("누적 실천횟수",  "+횟수 × 2 pts")
                    formulaRow("연속 실천일수",  "+일수 × 10 pts")
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("☀️")
                        Text("아침 챌린지 보너스")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    Text("해당 챌린지를 '아침 설정'하고 02:00~12:00 사이에 완료하면 전체 × 2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("← 챌린지 항목 왼쪽으로 스와이프 → 아침 설정/해제")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("예시")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("누적 20회, 연속 5일, 아침 수행")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("→ (300 + 40 + 50) × 2 = 780 pts")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
                .padding(.vertical, 2)
            }

            // MARK: - 추구미
            Section(header: sectionHeader("figure.mind.and.body", "추구미 포인트")) {
                row("🧘‍♀️", "참기",  "160 pts (고정)")
                row("🏋️‍♀️", "하기",  "160 pts (고정)")
            }

            // MARK: - 보상 사용
            Section(header: sectionHeader("gift.fill", "포인트 사용")) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("찡냥 스토어 충전")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("보상 항목의 [충전] 버튼을 누르면 포인트가 차감되고 수량이 1 추가됩니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .foregroundColor(.orange)
                        Text("삭제 시 자동 환불")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    Text("보상 항목을 삭제하면 남은 수량 × 포인트 비용만큼 자동으로 환불됩니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("예: 수량 3개 × 300 pts = 900 pts 환불")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                }
                .padding(.vertical, 2)
            }

            // MARK: - Today's Mission 자동 배정
            Section(header: sectionHeader("wand.and.stars", "자동 배정")) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("🎲")
                        Text("랜덤 Today's Mission")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    Text("매일 02:00 리셋 시, Quest에 남아있는 미완료 할 일 중 1개가 자동으로 Today's Mission에 등록됩니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("자동 배정된 항목은 당일 02:00 전 완료 시 ×3 보너스 적용")
                        .font(.caption)
                        .foregroundColor(.teal)
                        .fontWeight(.medium)
                }
                .padding(.vertical, 2)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("포인트 규칙")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    private func sectionHeader(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(title)
        }
        .textCase(nil)
        .font(.subheadline)
        .fontWeight(.semibold)
    }

    private func row(_ emoji: String, _ label: String, _ value: String) -> some View {
        HStack {
            Text(emoji)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
    }

    private func formulaRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }

    private func formulaBox(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
