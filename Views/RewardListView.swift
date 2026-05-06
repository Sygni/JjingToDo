//
//  RewardListView.swift
//  JjingToDo
//

import SwiftUI
import CoreData

struct RewardListView: View {
    @ObservedObject var user: UserEntity
    @Environment(\.managedObjectContext) var viewContext

    @State private var showingAddRewardSheet = false
    @State private var rewardToEdit: RewardEntity? = nil

    @FetchRequest(
        entity: RewardEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \RewardEntity.sortOrder, ascending: true)]
    ) var rewards: FetchedResults<RewardEntity>

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Text("보유 포인트")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("💎 \(user.points)")
                            .font(.headline)
                    }
                    .padding(.vertical, 2)
                }

                if rewards.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "gift")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("등록된 보상이 없어요")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            Spacer()
                        }
                    }
                } else {
                    Section(header:
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "gift.fill")
                                    .foregroundColor(.gray)
                                Text("Reward Tickets")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                            Divider()
                                .frame(maxWidth: .infinity)
                                .background(Color.accentColor)
                        }
                        .padding(.top, 4)
                        .background(Color.clear)
                        .textCase(nil)
                    ) {
                        ForEach(rewards) { reward in
                            RewardRowView(reward: reward, user: user, onRedeem: {
                                redeem(reward)
                            }, onCharge: {
                                charge(reward)
                            })
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(.secondarySystemGroupedBackground))
                                    .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 2)
                            )
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .swipeActions(edge: .leading) {
                                Button {
                                    rewardToEdit = reward
                                } label: {
                                    Label("수정", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                        .onDelete(perform: deleteRewards)
                        .onMove(perform: moveRewards)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("찡냥 스토어")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddRewardSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddRewardSheet) {
                AddRewardView(showingSheet: $showingAddRewardSheet, nextSortOrder: Int32(rewards.count))
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(item: $rewardToEdit) { reward in
                EditRewardView(reward: reward)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }

    private func redeem(_ reward: RewardEntity) {
        guard reward.remainingCount > 0 else { return }
        reward.remainingCount -= 1
        try? viewContext.save()
    }

    private func charge(_ reward: RewardEntity) {
        guard user.points >= reward.pointCost else { return }
        reward.remainingCount += 1
        user.points -= reward.pointCost
        try? viewContext.save()
    }

    private func deleteRewards(at offsets: IndexSet) {
        for i in offsets {
            let reward = rewards[i]
            let refund = reward.remainingCount * reward.pointCost
            if refund > 0 { user.points += refund }
            viewContext.delete(reward)
        }
        try? viewContext.save()
        reassignSortOrders()
    }

    private func moveRewards(from source: IndexSet, to destination: Int) {
        var reordered = Array(rewards)
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, reward) in reordered.enumerated() {
            reward.sortOrder = Int32(index)
        }
        try? viewContext.save()
    }

    private func reassignSortOrders() {
        for (index, reward) in rewards.enumerated() {
            reward.sortOrder = Int32(index)
        }
        try? viewContext.save()
    }
}

// MARK: - 보상 행

struct RewardRowView: View {
    @ObservedObject var reward: RewardEntity
    @ObservedObject var user: UserEntity
    let onRedeem: () -> Void
    let onCharge: () -> Void

    var canRedeem: Bool { reward.remainingCount > 0 }
    var canCharge: Bool { user.points >= reward.pointCost }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(reward.title ?? "보상")
                    .font(.headline)
                Spacer()
                Text("🎟️ \(reward.remainingCount)개")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(reward.remainingCount > 0 ? Color(hex: "#FFD6E0").opacity(0.6) : Color.gray.opacity(0.12))
                    .foregroundColor(reward.remainingCount > 0 ? Color(hex: "#C9778A") : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            HStack(spacing: 10) {
                Text("💎 \(reward.pointCost)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    onCharge()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                        Text("충전")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(canCharge ? Color.yellow.opacity(0.25) : Color.gray.opacity(0.1))
                    .foregroundColor(canCharge ? Color(hex: "#A07800") : .secondary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canCharge)

                Button {
                    onRedeem()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "minus")
                        Text("사용")
                    }
                    .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(canRedeem ? Color.mint.opacity(0.15) : Color.gray.opacity(0.1))
                        .foregroundColor(canRedeem ? .mint : .secondary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canRedeem)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 보상 수정 시트

struct EditRewardView: View {
    @ObservedObject var reward: RewardEntity
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var title: String = ""
    @State private var pointCost: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section("보상 이름") {
                    TextField("예: 달달한 커피", text: $title)
                        .submitLabel(.done)
                }
                Section("필요 포인트") {
                    TextField("예: 300", text: $pointCost)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("보상 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        if !title.isEmpty, let cost = Int32(pointCost), cost > 0 {
                            reward.title = title
                            reward.pointCost = cost
                            try? viewContext.save()
                        }
                        dismiss()
                    }
                    .disabled(title.isEmpty || Int32(pointCost) == nil)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("완료") { UIApplication.shared.endEditing() }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            title = reward.title ?? ""
            pointCost = "\(reward.pointCost)"
        }
    }
}
