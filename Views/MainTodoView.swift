//
//  MainTodoView.swift
//  HelloSwiftUI
//
//  Created by Jeongah Seo on 3/24/25.
//
import SwiftUI
import CoreData

struct MainTodoView: View {
    let user: UserEntity
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        entity: TaskEntity.entity(),
        sortDescriptors: []  // 정렬은 직접 해줄 거니까 비워도 됨
    ) private var taskEntities: FetchedResults<TaskEntity>
    
    @State private var newTask: String = ""
    @State private var newTaskText: String = "" // 20250329 키보드 외 영역 탭했을 때 키보드 내리기 위한 변수 추가
    //@State private var points: Int = 0    // 20250328 리워드 탭 확장 개선을 위한 변경
    @State private var totalPoints: Int = 0
    
    //Delete alert popup
    @State private var taskToDelete: TaskEntity? = nil
    @State private var showDeleteAlert = false
    
    //Reward system
    @State private var selectedRewardLevel: RewardLevel = .easy //default: 1 (easy)
    @State private var selectedTaskType: TaskType = .personal //default: 개인
    
    //Edit
    @State private var taskToEdit: TaskEntity? = nil
    @State private var editedTitle: String = ""
    @State private var showEditAlert = false
    
    let taskKey = "savedTasks"
    let pointKey = "savedPoints"
    let totalPointKey = "savedTotalPoints"
    
    var sortedTaskEntities: [TaskEntity] {
        let incomplete = taskEntities.filter { !$0.isCompleted }
            .sorted(by: { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) })
        
        let complete = taskEntities.filter { $0.isCompleted }
            .sorted(by: { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) })
        
        return incomplete + complete
    }

    var body: some View {
        
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.endEditing()
                }

            VStack {
                // 여기에 할 일 리스트나 다른 UI 추가
                VStack(spacing: 16) {
                    headerSection(points: user.points, totalPoints: totalPoints, viewContext: viewContext)
                    //couponSection(points: user.points, viewContext: viewContext) // 20250328 리워드 탭 확장 개선으로 Redemption 구조는 제거
                    inputSection(newTask: $newTask, viewContext: viewContext, selectedRewardLevel: selectedRewardLevel, saveContext: saveContext)
                    //rewardLevelPicker(selectedRewardLevel: $selectedRewardLevel) // 20250419 picker 추가로 이 부분 제거
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

                Spacer()
            }
        }
        
    }

    // 20250327 MARK: - View Components
    private func headerSection(points: Int32, totalPoints: Int, viewContext: NSManagedObjectContext) -> some View {
        VStack(spacing: 8) {
            Text(" 🐰찡냥 포인트: \(user.points)💎 ")
                .font(.headline)

            ProgressView(value: Double(points), total: 10000)
                .accentColor(Color(hex: "#FEDE00"))
                .padding(.horizontal)
            
            // 20250419 일단 빼기..
            /*
            Text("누적 기록: \(totalPoints)")
                .font(.subheadline)
                .foregroundColor(.gray)
             */
        }
    }

    private func inputSection(newTask: Binding<String>, viewContext: NSManagedObjectContext, selectedRewardLevel: RewardLevel, saveContext: @escaping () -> Void) ->  some View {
        VStack {
            HStack {
                TextField("할 일을 입력하세요", text: newTask)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .submitLabel(.done)
                
                Button("추가") {
                    if !newTask.wrappedValue.isEmpty {
                        let task = TaskEntity(context: viewContext)
                        task.id = UUID()
                        task.title = newTask.wrappedValue
                        task.isCompleted = false
                        task.createdAt = Date()
                        task.rewardLevelRaw = Int16(selectedRewardLevel.rawValue)
                        task.taskType = selectedTaskType

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
            
            HStack {
                Picker("타입", selection: $selectedTaskType) {
                    ForEach(TaskType.allCases, id: \.self) { type in
                        Label(type.label, systemImage: type.icon)
                            .tag(type)
                    }
                }
                .frame(width: 150, height: 30)
                .pickerStyle(SegmentedPickerStyle())
                
                Picker("난이도", selection: $selectedRewardLevel) {
                    Text(RewardLevel.easy.label)
                        .tag(RewardLevel.easy)
                    Text(RewardLevel.normal.label)
                        .tag(RewardLevel.normal)
                    Text(RewardLevel.hard.label)
                        .tag(RewardLevel.hard)
                    Text(RewardLevel.veryHard.label)
                        .tag(RewardLevel.veryHard)
                }
                .frame(width: 200, height: 30)
                .pickerStyle(SegmentedPickerStyle())
            }
            .padding(.horizontal)
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

                    Image(systemName: task.taskType.icon)
                        //.font(.caption)
                        .foregroundColor(task.taskType.color)
                    
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
    
    @MainActor
    private func toggleTask(_ task: TaskEntity) {
        task.isCompleted.toggle()
        task.completedAt = task.isCompleted ? Date() : nil

        let point = task.reward.pointValue

        if task.isCompleted {
            user.points += Int32(point)
            totalPoints += point
        } else {
            if(user.points - Int32(point) >= 0){
                user.points -= Int32(point)
                totalPoints -= point
            }
            else{
                user.points = 0
                totalPoints = 0
            }
                
        }

        //saveContext()
        try? viewContext.save()
    }
    
    func deleteTask(_ task: TaskEntity) {
        if task.isCompleted {
            user.points -= Int32(task.reward.pointValue)
            totalPoints -= task.reward.pointValue
        }

        viewContext.delete(task)
        try? viewContext.save()
        //saveContext()
    }
    
    func deleteTask(at offsets: IndexSet) {
        for index in offsets {
            let task = sortedTaskEntities[index]

            if task.isCompleted {
                user.points -= Int32(task.reward.pointValue)
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

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let userRequest = NSFetchRequest<UserEntity>(entityName: "UserEntity")
    let user = (try? context.fetch(userRequest).first) ?? {
        let newUser = UserEntity(context: context)
        newUser.id = UUID()
        newUser.points = 0
        newUser.joinedAt = Date()
        try? context.save()
        return newUser
    }()
    
    return MainTodoView(user: user).environment(\.managedObjectContext, context)
}
