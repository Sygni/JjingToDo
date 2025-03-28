import SwiftUI

struct ContentView: View {
    
    @Environment(\.managedObjectContext) private var viewContext
    
    //@State private var tasks: [Task] = []     // 20250327 CoreData 추가로 리팩토링 - TaskEntity 기반으로 변경
    //@State private var redemptions: [Redemption] = [] // 20250328 리워드 탭 확장 개선으로 Redemption 구조는 제거
    
    @State private var refreshToken = UUID()    // 20250328 Debug View 리프레시용
    
    // UserEntity Fetch
    @FetchRequest(
        entity: UserEntity.entity(),
        sortDescriptors: []
    ) var users: FetchedResults<UserEntity>
    
    var body: some View {
        
        if let user = users.first {
            TabView {
                //MainTodoView(tasks: $tasks, redemptions: $redemptions)    // 20250327
                MainTodoView(user: users.first!)
                    .tabItem {
                        Label("이겨내🔥", systemImage: "checkmark.circle")
                    }
                    .id(refreshToken)
                    //.tint(Color(hex: "#68BBE3"))  //안 먹히는듯...

                //RedemptionHistoryView(tasks: $tasks, redemptions: $redemptions)   // 20250327
                // 20250328 리워드 탭 확장 개선으로 Redemption 구조는 제거
/*                RedemptionHistoryView()
                    .tabItem {
                        Label("보상 기록", systemImage: "list.bullet.rectangle")
                    }
                    //.tint(Color(hex: "#68BBE3"))
*/
                // 20250328 Reward 구조 확장 개선
                RewardListView(user: user)
                    .tabItem {
                        Label("보상", systemImage: "gift")
                    }
                    .id(refreshToken)
                
#if DEBUG
                DebugToolView(refreshTrigger: $refreshToken)
                    .tabItem {
                        Label("디버그", systemImage: "wrench.and.screwdriver")
                    }
                    .id(refreshToken)
#endif
            }
            .accentColor(Color(hex: "#68BBE3"))
        } else {
            // 유저가 없으면 자동 생성
            Color.clear
                .onAppear {
                    createUser()
                }
        }
        
    }
    
    private func createUser() {
            let newUser = UserEntity(context: viewContext)
            newUser.id = UUID()
#if DEBUG
            newUser.points = 10000
#else
            newUser.points = 0
#endif
            newUser.joinedAt = Date()
            try? viewContext.save()
        }
}

let taskKey = "tasks"
let redemptionKey = "redemptions"

func saveData(tasks: [Task], redemptions: [Redemption]) {
    if let encodedTasks = try? JSONEncoder().encode(tasks) {
        UserDefaults.standard.set(encodedTasks, forKey: taskKey)
    }
    if let encodedRedemptions = try? JSONEncoder().encode(redemptions) {
        UserDefaults.standard.set(encodedRedemptions, forKey: redemptionKey)
    }
}

func loadData() -> ([Task], [Redemption]) {
    var tasks: [Task] = []
    var redemptions: [Redemption] = []

    if let savedTasks = UserDefaults.standard.data(forKey: taskKey),
       let decodedTasks = try? JSONDecoder().decode([Task].self, from: savedTasks) {
        tasks = decodedTasks
    }

    if let savedRedemptions = UserDefaults.standard.data(forKey: redemptionKey),
       let decodedRedemptions = try? JSONDecoder().decode([Redemption].self, from: savedRedemptions) {
        redemptions = decodedRedemptions
    }

    return (tasks, redemptions)
}
