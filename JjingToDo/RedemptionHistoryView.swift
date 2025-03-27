//
//  RedemptionHistoryView.swift
//  HelloSwiftUI
//
//  Created by Jeongah Seo on 3/24/25.
//
import SwiftUI
import CoreData

struct RedemptionHistoryView: View {
    // 저장된 기록 불러오기
    //@State private var redemptions: [Redemption] = []
    // 20250327 CoreData 추가로 리팩토링 - 삭제
    //@Binding var tasks: [Task]
    //@Binding var redemptions: [Redemption]
    
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        entity: RedemptionEntity.entity(),
        sortDescriptors: []  // 직접 정렬할 거니까 비워둠
    ) private var redemptionEntities: FetchedResults<RedemptionEntity>
    
    //let redemptionKey = "savedRedemptions"    // 20250327 CoreData 추가로 리팩토링 - 삭제

    var sortedRedemptions: [RedemptionEntity] {
        redemptionEntities.sorted {
            if $0.isUsed == $1.isUsed {
                // 같은 상태일 때는 날짜 순
                return ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
            } else {
                // 미사용 먼저
                return !$0.isUsed
            }
        }
    }
    
    var body: some View {
        NavigationView {
            
            // 20250327 CoreData 추가로 리팩토링 - 삭제
            /*
             let sortedRedemptions = redemptions.sorted {
             if $0.isUsed == $1.isUsed {
             return $0.date > $1.date  // 같은 사용 상태일 땐 최근 순
             } else {
             return !$0.isUsed  // 미사용이 먼저
             }
             }
             */
            VStack(spacing: 0) {
                List(sortedRedemptions) { redemption in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("💸 \(redemption.amount + 1000)원 쿠폰")
                                .font(.headline)
                            Text(redemption.isUsed ? "☑️ 사용 완료" : "🏆 미사용")
                                .font(.caption)
                                .foregroundColor(redemption.isUsed ? .gray : .orange)
                            //Text(redemption.date.formatted(date: .abbreviated, time: .shortened)) // 20250327
                            Text(redemption.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "")
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
                
#if DEBUG
                Text(versionString)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
#endif
            }
        }
        .navigationTitle("쿠폰 교환 기록")
    }
 
#if DEBUG
    // 버전 정보 표시용 변수
    var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "버전 \(version) (\(build))"
    }
#endif
    
    // 20250327 CoreData 추가로 리팩토링 - 대체
    /*
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
     */
    func markRedemptionUsed(_ redemption: RedemptionEntity) {
            redemption.isUsed = true
            saveContext()
        }

    func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("⚠️ Core Data 저장 실패: \(error)")
        }
    }
}

