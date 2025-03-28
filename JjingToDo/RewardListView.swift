//
//  RewardListView.swift
//  JjingToDo
//
//  Created by Jeongah Seo on 3/28/25.
//

import SwiftUI
import CoreData

struct RewardListView: View {
    @ObservedObject var user: UserEntity
    @Environment(\.managedObjectContext) var viewContext
    
    @State private var showingAddRewardSheet = false
    @FetchRequest(
        entity: RewardEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \RewardEntity.createdAt, ascending: false)]
    ) var rewards: FetchedResults<RewardEntity>

    var body: some View {
        NavigationView {
            Group {
                if rewards.isEmpty {
                    Text("보상이 아직 없어요!")
                        .foregroundColor(.gray)
                        .font(.title3)
                } else {
                    List {
                        Section {
                            Text("현재 포인트: \(user.points)💎")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        ForEach(rewards) { reward in
                            VStack(alignment: .leading) {
                                Text(reward.title ?? "보상 이름 없음")
                                    .font(.headline)
                                HStack {
                                    Text("포인트: \(reward.pointCost)")
                                    Spacer()
                                    Text("남은 수량: \(reward.remainingCount)")
                                }
                                .font(.subheadline)

                                Button(action: {
                                    print("🔧 보상 받기 호출됨!")
                                    redeem(reward)
                                }) {
                                    Text("받기")
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue)
                                        .cornerRadius(8)
                                }
                                .disabled(reward.remainingCount <= 0)
                                .buttonStyle(BorderlessButtonStyle())
                                //.listRowBackground(Color.clear)   //테스트 안 해본 코드

                                Button(action: {
                                    charge(reward)
                                }) {
                                    Image(systemName: "plus.circle")
                                        .font(.title2)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.top, 4)
                                .disabled(user.points < reward.pointCost)
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())  // 이거 넣었을 때 리스트 영역 터치해도 버튼 눌릴 때도 있었으므로 확인 요망
                            .onTapGesture {
                                // 아무것도 안 하기
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("보상 목록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("보상 추가") {
                    showingAddRewardSheet = true
                }
            }
            .sheet(isPresented: $showingAddRewardSheet) {
                AddRewardView(showingSheet: $showingAddRewardSheet)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        .onAppear {
            print("🧩 RewardListView points: \(user.points)")
        }
    }

    private func redeem(_ reward: RewardEntity) {
        print("🔧 redeem() called for \(reward.title ?? "보상")")  // 디버깅
        print("현재 포인트: \(user.points), 보상 포인트: \(reward.pointCost), 남은 수량: \(reward.remainingCount)")  // 디버깅

        guard reward.remainingCount > 0 else {
            print("❌ 남은 수량이 없습니다!")
            return
        }
        /*guard user.points >= reward.pointCost else {
            print("❌ 포인트 부족!")
            return
        }
         */

        // 차감 처리
        reward.remainingCount -= 1
        //user.points -= reward.pointCost

        do {
            try viewContext.save()
            print("🎉 보상 수령 완료!")
        } catch {
            print("❌ 보상 수령 실패: \(error.localizedDescription)")
        }
    }

    private func charge(_ reward: RewardEntity) {
        print("🔧 charge() called for \(reward.title ?? "보상")")  // 디버깅

        guard user.points >= reward.pointCost else {
            print("❌ 포인트 부족")
            return
        }

        reward.remainingCount += 1
        user.points -= reward.pointCost  // 포인트 차감

        do {
            try viewContext.save()
            print("💰 보상 교환 성공")
        } catch {
            print("❌ 저장 실패: \(error.localizedDescription)")
        }
    }
}
