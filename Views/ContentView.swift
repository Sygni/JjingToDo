import SwiftUI

struct ContentView: View {
    
    @Environment(\.managedObjectContext) private var viewContext
    
    // 20250422 새벽 2시에 백그라운드 작업 안 도는 문제 해결
    @Environment(\.scenePhase) private var scenePhase
    
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
  
                // 20250421 챌린지 탭 추가
                ChallengeTabView()
                    .tabItem {
                        Label("챌린지", systemImage: "sparkles")
                    }
                    .id(refreshToken)
                
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
            .onChange(of: scenePhase) { newPhase in     // 20250422 오늘의할일 새벽 2시 리셋용
                if newPhase == .active {
                    print("🌞 scenePhase.active → todayQueue 강제 체크")
                    TodayQueueManager.shared.resetExpiredTodayTasks()
                }
            }
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
            newUser.points = 0
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
