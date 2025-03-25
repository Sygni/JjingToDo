import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            MainTodoView()
                .tabItem {
                    Label("이겨내🔥", systemImage: "checkmark.circle")
                }
                //.tint(Color(hex: "#68BBE3"))

            RedemptionHistoryView()
                .tabItem {
                    Label("보상 기록", systemImage: "list.bullet.rectangle")
                }
                //.tint(Color(hex: "#68BBE3"))
        }
        .accentColor(Color(hex: "#68BBE3"))
    }
}

