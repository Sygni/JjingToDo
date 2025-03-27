//
//  MainTodoView.swift
//  HelloSwiftUI
//
//  Created by Jeongah Seo on 3/24/25.
//
import SwiftUI
import CoreData


struct MainTodoView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        entity: TaskEntity.entity(),
        sortDescriptors: []  // 정렬은 직접 해줄 거니까 비워도 됨
    ) private var taskEntities: FetchedResults<TaskEntity>
    
    @State private var newTask: String = ""
    @State private var points: Int = 0
    @State private var totalPoints: Int = 0
    
    //    @State private var tasks: [Task] = []  // 20250325 ContentView로 이동
    //@Binding var tasks: [Task]    // 20250327 CoreData 추가로 리팩토링
    //    @State private var redemptions: [Redemption] = [] // 20250325 ContentView로 이동
    @Binding var redemptions: [Redemption]
    
    //Delete alert popup
    //@State private var taskToDelete: Task? = nil    // 20250327
    @State private var taskToDelete: TaskEntity? = nil
    @State private var showDeleteAlert = false
    
    //Reward system
    @State private var selectedRewardLevel: RewardLevel = .easy //default: 1 (easy)
    
    //Edit
    //@State private var taskToEdit: Task? = nil    // 20250327
    @State private var taskToEdit: TaskEntity? = nil
    @State private var editedTitle: String = ""
    @State private var showEditAlert = false
    
    let redemptionKey = "savedRedemptions"
    let taskKey = "savedTasks"
    let pointKey = "savedPoints"
    let totalPointKey = "savedTotalPoints"
    
    // 20250327 CoreData 추가로 리팩토링 - 대체
    /*
     var sortedTasks: [Task] {
     let incomplete = tasks.filter { !$0.isCompleted }
     .sorted(by: { $0.createdAt > $1.createdAt })
     
     let complete = tasks.filter { $0.isCompleted }
     .sorted(by: {
     ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)
     })
     
     return incomplete + complete
     }
     */
    
    var sortedTaskEntities: [TaskEntity] {
        let incomplete = taskEntities.filter { !$0.isCompleted }
            .sorted(by: { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) })
        
        let complete = taskEntities.filter { $0.isCompleted }
            .sorted(by: { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) })
        
        return incomplete + complete
    }
    
    // 20250327 같은 코드지만 일단 위 버전으로 하기로
    /*
     var sortedTaskEntities: [TaskEntity] {
     taskEntities.sorted {
     if $0.isCompleted == $1.isCompleted {
     // 같은 완료 상태일 경우, 완료된 경우는 completedAt, 나머지는 createdAt 기준
     let lhsDate = $0.completedAt ?? $0.createdAt ?? .distantPast
     let rhsDate = $1.completedAt ?? $1.createdAt ?? .distantPast
     return lhsDate > rhsDate
     } else {
     // 미완료가 위로 올라오게
     return !$0.isCompleted
     }
     }
     }
     */
    
    var body: some View {
        VStack(spacing: 16) {
            headerSection(points: points, totalPoints: totalPoints, viewContext: viewContext)
            couponSection(points: points, viewContext: viewContext)
            inputSection(newTask: $newTask, viewContext: viewContext, selectedRewardLevel: selectedRewardLevel, saveContext: saveContext)
            rewardLevelPicker(selectedRewardLevel: $selectedRewardLevel)
            taskListSection(
                sortedTasks: sortedTaskEntities,
                taskToEdit: $taskToEdit,
                taskToDelete: $taskToDelete,
                editedTitle: $editedTitle,
                showEditAlert: $showEditAlert,
                showDeleteAlert: $showDeleteAlert,
                toggleTask: toggleTask
            )
            
        }
        .alert("이 항목을 삭제할까요?", isPresented: $showDeleteAlert, presenting: taskToDelete) { task in
            Button("삭제", role: .destructive) {
                deleteTask(task)
            }
            Button("취소", role: .cancel) { }
        } message: { task in
            //Text("\"\(task.title)\"를 삭제하면 복구할 수 없습니다.")
            Text("항목을 삭제하면 복구할 수 없습니다.")
        }
        .alert("할 일 수정", isPresented: $showEditAlert, actions: {
            TextField("제목", text: $editedTitle)
            // 20250327 CoreData 추가로 리팩토링 - 대체
            /*
             Button("저장", role: .none) {
             if let taskToEdit = taskToEdit,
             let index = tasks.firstIndex(where: { $0.id == taskToEdit.id }) {
             tasks[index] = Task(
             id: taskToEdit.id,
             title: editedTitle,
             isCompleted: taskToEdit.isCompleted,
             createdAt: taskToEdit.createdAt,
             completedAt: taskToEdit.completedAt,
             reward: taskToEdit.reward
             )
             saveData(tasks: tasks, redemptions: redemptions)
             }
             }
             */
            Button("저장", role: .none) {
                if let taskToEdit = taskToEdit {
                    taskToEdit.title = editedTitle
                    saveContext()
                }
            }
            Button("취소", role: .cancel) { }
        }, message: {
            Text("할 일 제목을 수정하세요")
        })
        .padding()
    // 20250327 CoreData 추가로 리팩토링 - 제거
    /*
     .onAppear {
     (tasks, redemptions) = loadData()
     }
     */
    
    }

    // 20250327 MARK: - View Components
    private func headerSection(points: Int, totalPoints: Int, viewContext: NSManagedObjectContext) -> some View {
        VStack(spacing: 8) {
            Text(" 🐰찡냥 포인트: \(points)💎 ")
                .font(.headline)

            ProgressView(value: Double(points), total: 10000)
                .accentColor(Color(hex: "#FEDE00"))
                .padding(.horizontal)

            if points >= 5000 {
                Button("💸 5,000원 쿠폰 받기") {
                    // 20250327 CoreData 추가로 리팩토링
                    /*
                    let redemption = Redemption(id: UUID(), amount: 5000, date: Date())
                    redemptions.append(redemption)
                    //print(redemptions.count)    //TEST
                    points -= 5000
                    saveData(tasks: tasks, redemptions: redemptions)
                    */
                    let newRedemption = RedemptionEntity(context: viewContext)
                    newRedemption.id = UUID()
                    newRedemption.amount = 5000
                    newRedemption.createdAt = Date()
                    newRedemption.isUsed = false
                    try? viewContext.save()
                }
                .padding(8)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(8)
            }

            Text("누적 기록: \(totalPoints)")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }

    private func couponSection(points: Int, viewContext: NSManagedObjectContext) -> some View {
        VStack(spacing: 8) {
            if points >= 10000 {
                Button("💸 11,000원 쿠폰 받기") {
                    // 20250327 CoreData 추가로 리팩토링
                    /*
                    let redemption = Redemption(id: UUID(), amount: 10000, date: Date())
                    redemptions.append(redemption)
                    //print(redemptions.count)    //TEST
                    points -= 10000
                    saveData(tasks: tasks, redemptions: redemptions)
                    */
                    let newRedemption = RedemptionEntity(context: viewContext)
                    newRedemption.id = UUID()
                    newRedemption.amount = 10000
                    newRedemption.createdAt = Date()
                    newRedemption.isUsed = false
                    try? viewContext.save()
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
            }*/
            Button("디버그 포인트") {
                toggleDebugPoints()
            }
#endif
             

        }
    }

    private func inputSection(newTask: Binding<String>, viewContext: NSManagedObjectContext, selectedRewardLevel: RewardLevel, saveContext: @escaping () -> Void) ->  some View {
            // 20250327 CoreData 추가로 리팩토링 - 대체
            HStack {
                TextField("할 일을 입력하세요", text: newTask)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .submitLabel(.done)
                
                Button("추가") {
                    // 20250327 CoreData 추가로 리팩토링 - 대체
                    /*
                    if !newTask.isEmpty {
                        let task = Task(title: newTask, reward: selectedRewardLevel)
                        tasks.append(task)
                        newTask = ""
                        saveData(tasks: tasks, redemptions: redemptions)
                    }
                     */
                    if !newTask.wrappedValue.isEmpty {
                        let task = TaskEntity(context: viewContext)
                        task.id = UUID()
                        task.title = newTask.wrappedValue
                        task.isCompleted = false
                        task.createdAt = Date()
                        task.rewardLevelRaw = Int16(selectedRewardLevel.rawValue)

                        newTask.wrappedValue = ""
                        saveContext()
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(Color(hex: "#68BBE3"))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()

        }

    private func rewardLevelPicker(selectedRewardLevel: Binding<RewardLevel>) -> some View {
        Picker("난이도", selection: selectedRewardLevel) {
            Text(RewardLevel.easy.label)
                .tag(RewardLevel.easy)
            Text(RewardLevel.normal.label)
                .tag(RewardLevel.normal)
            Text(RewardLevel.hard.label)
                .tag(RewardLevel.hard)
        }
        .pickerStyle(SegmentedPickerStyle())
    }

    private func taskListSection(
        sortedTasks: [TaskEntity],
        taskToEdit: Binding<TaskEntity?>,
        taskToDelete: Binding<TaskEntity?>,
        editedTitle: Binding<String>,
        showEditAlert: Binding<Bool>,
        showDeleteAlert: Binding<Bool>,
        toggleTask: @escaping (TaskEntity) -> Void
    ) -> some View {
        List {
            ForEach(sortedTasks) { task in
                HStack {
                    Button {
                        toggleTask(task)
                    } label: {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(task.isCompleted ? task.reward.color : .gray)
                    }

                    Text(task.safeTitle)
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .gray : task.reward.color)
                }
                .swipeActions(edge: .trailing) {
                    Button {
                        taskToEdit.wrappedValue = task
                        editedTitle.wrappedValue = task.safeTitle
                        showEditAlert.wrappedValue = true
                    } label: {
                        Label("수정", systemImage: "pencil")
                    }
                    .tint(.blue)

                    Button(role: .destructive) {
                        taskToDelete.wrappedValue = task
                        showDeleteAlert.wrappedValue = true
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                    .tint(.red)
                }
            }
        }
    }


    // 20250327 CoreData 추가로 리팩토링 - 아래 함수들로 대체
    /*
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
     */
    
    @MainActor
    private func toggleTask(_ task: TaskEntity) {
        task.isCompleted.toggle()
        task.completedAt = task.isCompleted ? Date() : nil

        let point = task.reward.pointValue

        if task.isCompleted {
            points += point
            totalPoints += point
        } else {
            points -= point
            totalPoints -= point
        }

        saveContext()
    }
    
    func deleteTask(_ task: TaskEntity) {
        if task.isCompleted {
            points -= task.reward.pointValue
            totalPoints -= task.reward.pointValue
        }

        viewContext.delete(task)
        saveContext()
    }
    
    func deleteTask(at offsets: IndexSet) {
        for index in offsets {
            let task = sortedTaskEntities[index]

            if task.isCompleted {
                points -= task.reward.pointValue
                totalPoints -= task.reward.pointValue
            }

            viewContext.delete(task)
        }

        saveContext()
    }
    
    // 20250327 CoreData 추가로 리팩토링 - 아래 함수도 추가
    func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("⚠️ Core Data 저장 실패: \(error)")
        }
    }
    
    #if DEBUG
    func toggleDebugPoints() {
        points = 10000
        totalPoints = 10000
        saveContext()
    }
    #endif
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
