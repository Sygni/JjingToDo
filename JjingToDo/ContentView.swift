import SwiftUI

struct ContentView: View {
    
    @State private var tasks: [Task] = []
    @State private var redemptions: [Redemption] = []
    
    var body: some View {
        TabView {
            MainTodoView(tasks: $tasks, redemptions: $redemptions)
                .tabItem {
                    Label("이겨내🔥", systemImage: "checkmark.circle")
                }
                //.tint(Color(hex: "#68BBE3"))

            RedemptionHistoryView(tasks: $tasks, redemptions: $redemptions)
                .tabItem {
                    Label("보상 기록", systemImage: "list.bullet.rectangle")
                }
                //.tint(Color(hex: "#68BBE3"))
        }
        .accentColor(Color(hex: "#68BBE3"))
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
