//
//  MainTodoView.swift
//  HelloSwiftUI
//
//  Created by Jeongah Seo on 3/24/25.
//
import SwiftUI



struct MainTodoView: View {
    @State private var newTask: String = ""
    @State private var tasks: [Task] = []
    @State private var points: Int = 0
    @State private var totalPoints: Int = 0
    @State private var redemptions: [Redemption] = []
    
    //Delete alert popup
    @State private var taskToDelete: Task? = nil
    @State private var showDeleteAlert = false
    
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
                    points -= 5000
                    saveData()
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
                    points -= 10000
                    saveData()
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
                saveData()
            }*/
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
                        let task = Task(title: newTask)
                        tasks.append(task)
                        newTask = ""
                        saveData()
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(Color(hex: "#68BBE3"))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()

            
            List {
                ForEach(sortedTasks.indices, id: \.self) { index in
                    let task = sortedTasks[index]
                    HStack {
                        Button(action: {
                            
                            toggleTask(task)

                        }) {

                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(task.isCompleted ? Color(hex: "79e5cb") : .gray)
                        }

                        Text(task.title)
                            .strikethrough(task.isCompleted)
                            .foregroundColor(task.isCompleted ? .gray : .primary)
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
            loadData()
        }

    }

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
    
    func toggleTask(_ task: Task) {
        if let i = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[i].isCompleted.toggle()
            if tasks[i].isCompleted {
                points += 100
                totalPoints += 100
                tasks[i].completedAt = Date()
            } else {
                points -= 100
                totalPoints -= 100
                tasks[i].completedAt = nil
            }
            saveData()
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
        saveData()
    }
    
    func deleteTask(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            if tasks[index].isCompleted {
                points -= 100
                totalPoints -= 100
            }
            tasks.remove(at: index)
            saveData()
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
