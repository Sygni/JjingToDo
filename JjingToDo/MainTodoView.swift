//
//  MainTodoView.swift
//  HelloSwiftUI
//
//  Created by Jeongah Seo on 3/24/25.
//
import SwiftUI



struct MainTodoView: View {
    @State private var newTask: String = ""
    @State private var points: Int = 0
    @State private var totalPoints: Int = 0

    //    @State private var tasks: [Task] = []  // 20250325 ContentView로 이동
    @Binding var tasks: [Task]
    //    @State private var redemptions: [Redemption] = [] // 20250325 ContentView로 이동
    @Binding var redemptions: [Redemption]
    
    //Delete alert popup
    @State private var taskToDelete: Task? = nil
    @State private var showDeleteAlert = false
    
    //Reward system
    @State private var selectedRewardLevel: RewardLevel = .easy //default: 1 (easy)
    
    let redemptionKey = "savedRedemptions"
    let taskKey = "savedTasks"
    let pointKey = "savedPoints"
    let totalPointKey = "savedTotalPoints"

    var sortedTasks: [Task] {
        let incomplete = tasks.filter { !$0.isCompleted }
            .sorted(by: { $0.createdAt > $1.createdAt })

        let complete = tasks.filter { $0.isCompleted }
            .sorted(by: {
                ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)
            })

        return incomplete + complete
    }
    
    var body: some View {
        VStack(spacing: 16) {
            /*Color.clear // 터치 영역 확보
                    .onTapGesture {
                        UIApplication.shared.endEditing()
                    }
            */
            Text(" 🐰찡냥 포인트: \(points)💎 ")
                .font(.headline)

            ProgressView(value: Double(points), total: 10000)
                .accentColor(Color(hex: "#FEDE00"))
                .padding(.horizontal)

            if points >= 5000 {
                Button("💸 5,000원 쿠폰 받기") {
                    let redemption = Redemption(id: UUID(), amount: 5000, date: Date())
                    redemptions.append(redemption)
                    //print(redemptions.count)    //TEST
                    points -= 5000
                    saveData(tasks: tasks, redemptions: redemptions)
                }
                .padding(8)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(8)
            }

            if points >= 10000 {
                Button("💸 11,000원 쿠폰 받기") {
                    let redemption = Redemption(id: UUID(), amount: 10000, date: Date())
                    redemptions.append(redemption)
                    //print(redemptions.count)    //TEST
                    points -= 10000
                    saveData(tasks: tasks, redemptions: redemptions)
                }
                .padding(8)
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            #if DEBUG
            /*Button("디버그 포인트") {
                points = 10000
                totalPoints = 10000
                saveData(tasks: tasks, redemptions: redemptions)
            }
             */
            #endif
            
            Text("누적 기록: \(totalPoints)")
                .font(.subheadline)
                .foregroundColor(.gray)
     
            
            HStack {
                TextField("할 일을 입력하세요", text: $newTask)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .submitLabel(.done)
                
                Button("추가") {
                    if !newTask.isEmpty {
                        let task = Task(title: newTask, reward: selectedRewardLevel)
                        tasks.append(task)
                        newTask = ""
                        saveData(tasks: tasks, redemptions: redemptions)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(Color(hex: "#68BBE3"))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()

            Picker("난이도", selection: $selectedRewardLevel) {
                Text(RewardLevel.easy.label)
                    .tag(RewardLevel.easy)
                Text(RewardLevel.normal.label)
                    .tag(RewardLevel.normal)
                Text(RewardLevel.hard.label)
                    .tag(RewardLevel.hard)
            }
            .pickerStyle(SegmentedPickerStyle())  // 세그먼트 스타일로 보이게
            //.foregroundColor(Color.mint)      // 안 먹힘.. WHY???
            //.pickerStyle(MenuPickerStyle())  // 스타일을 Menu로 변경
            
            List {
                ForEach(sortedTasks.indices, id: \.self) { index in
                    let task = sortedTasks[index]
                    HStack {
                        Button(action: {
                            
                            toggleTask(task)

                        }) {

                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                //.foregroundColor(task.isCompleted ? Color(hex: "79e5cb") : .gray)
                                .foregroundColor(task.isCompleted ? task.reward.color : .gray)
                        }

                        Text(task.title)
                            .strikethrough(task.isCompleted)
                            //.foregroundColor(task.isCompleted ? .gray : .primary)
                            .foregroundColor(task.isCompleted ? .gray : task.reward.color)
                    }
                }
                .onDelete { offsets in
                    if let index = offsets.first {
                        let task = sortedTasks[index]
                        taskToDelete = task
                        showDeleteAlert = true
                    }
                }
            }
            .alert("이 항목을 삭제할까요?", isPresented: $showDeleteAlert, presenting: taskToDelete) { task in
                Button("삭제", role: .destructive) {
                    deleteTask(task)
                }
                Button("취소", role: .cancel) { }
            } message: { task in
                Text("\"\(task.title)\"를 삭제하면 복구할 수 없습니다.")
            }
        }
        .padding()
        .onAppear {
            (tasks, redemptions) = loadData()
        }

    }

    
/*
    // 20250325 ContentView.swift로 이동
    func saveData() {
        if let encodedTasks = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encodedTasks, forKey: taskKey)
        }
        UserDefaults.standard.set(points, forKey: pointKey)
        UserDefaults.standard.set(totalPoints, forKey: totalPointKey)
        
        
        if let encodedRedemptions = try? JSONEncoder().encode(redemptions) {
            UserDefaults.standard.set(encodedRedemptions, forKey: redemptionKey)
        }

        UserDefaults.standard.synchronize()
    }

 // 20250325 ContentView.swift로 이동
    func loadData() {
        if let savedTasks = UserDefaults.standard.data(forKey: taskKey),
           let decodedTasks = try? JSONDecoder().decode([Task].self, from: savedTasks) {
            tasks = decodedTasks
        }
        points = UserDefaults.standard.integer(forKey: pointKey)
        totalPoints = UserDefaults.standard.integer(forKey: totalPointKey)
        
        if let savedRedemptions = UserDefaults.standard.data(forKey: redemptionKey),
           let decodedRedemptions = try? JSONDecoder().decode([Redemption].self, from: savedRedemptions) {
            redemptions = decodedRedemptions
        }
    }
 */
    
    func toggleTask(_ task: Task) {
        if let i = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[i].isCompleted.toggle()
            if tasks[i].isCompleted {
                points += task.reward.points
                totalPoints += task.reward.points
                tasks[i].completedAt = Date()
            } else {
                points -= task.reward.points
                totalPoints -= task.reward.points
                tasks[i].completedAt = nil
            }
            saveData(tasks: tasks, redemptions: redemptions)
        }
    }
    
    func deleteTask(at offsets: IndexSet) {
        for index in offsets {
            let task = sortedTasks[index]
            if let originalIndex = tasks.firstIndex(where: { $0.id == task.id }) {
                // 포인트 차감 처리도 같이 해주기!
                if tasks[originalIndex].isCompleted {
                    points -= 100
                    totalPoints -= 100
                }
                tasks.remove(at: originalIndex)
            }
        }
        saveData(tasks: tasks, redemptions: redemptions)
    }
    
    func deleteTask(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            if tasks[index].isCompleted {
                points -= 100
                totalPoints -= 100
            }
            tasks.remove(at: index)
            saveData(tasks: tasks, redemptions: redemptions)
        }
    }
}

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}


extension Color {
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexSanitized.hasPrefix("#") {
            hexSanitized.remove(at: hexSanitized.startIndex)
        }
        
        let scanner = Scanner(string: hexSanitized)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        
        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
