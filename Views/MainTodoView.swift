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
    @Environment(\.managedObjectContext) /*private*/ var viewContext
    
    @FetchRequest(
        entity: TaskEntity.entity(),
        sortDescriptors: []  // 정렬은 직접 해줄 거니까 비워도 됨
    ) /*private*/ var taskEntities: FetchedResults<TaskEntity>
    
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
    
    // 20250420 오늘의할일 기능 추가
    @State /*private*/ var showTodayLimitAlert = false
    @State /*private*/ var todayLimitMessage = ""
    
    // 20250423 투두리스트에 타입 필터 추가
    @State /*private*/ var selectedFilterType: TaskType? = nil  // 전체(default nil), 개인/업무/공부 등
    
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

            VStack {
                // 여기에 할 일 리스트나 다른 UI 추가
                VStack(spacing: 16) {
                    headerSection(points: user.points, totalPoints: totalPoints, viewContext: viewContext)
                    inputSection(newTask: $newTask, viewContext: viewContext, selectedRewardLevel: selectedRewardLevel, saveContext: saveContext)
                    
                    // 20250420 오늘의할일 기능 추가
                    List {
                        // ── 오늘 할 일 섹션 ───────────────────────────────────
                        if !todayTasks.isEmpty {
                            Section {
                                ForEach(todayTasks) { task in
                                    //taskRow(task)
                                    taskRow(
                                        task,
                                        taskToEdit: $taskToEdit,
                                        editedTitle: $editedTitle,
                                        showEditAlert: $showEditAlert,
                                        taskToDelete: $taskToDelete,
                                        showDeleteAlert: $showDeleteAlert
                                    )
                                    .listRowBackground(
                                        Color(UIColor.systemMint).opacity(0.10)    // 🎨 원하는 톤으로
                                    )
                                }
                            } header: {
                                VStack(alignment: .leading, spacing: 4){
                                    HStack(spacing: 4) {
                                        Image(systemName: "trophy")
                                            .foregroundColor(.gray)
                                        Text("Today's Mission")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                    }
                                    Divider()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.accentColor)
                                }
                                .padding(.top, 4)
                                //.padding(.leading, -8)      // 리스트 인셋 만큼 보정
                                .background(Color(.systemBackground))
                            }
                        }

                        // ── 기본 태스크 섹션 ──────────────────────────────
                        Section(
                            header:
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Image(systemName: "flag.checkered")
                                            .foregroundColor(.gray)
                                        Text("Quest")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                    }
                                    
                                    // 20250423 투두리스트에 타입 필터 추가
                                    // 슬라이딩 타입이 불편(항목 4개) --> 추후 개선
                                    Picker("필터", selection: $selectedFilterType) {
                                        Text("전체").tag(nil as TaskType?)
                                        ForEach(TaskType.allCases, id: \.self) { type in
                                            Text(type.label).tag(type as TaskType?)
                                        }
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                    //.padding(.bottom, 8)
                                    Divider()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.accentColor)
                                }
                                .padding(.top, 6)
                                .padding(.leading, -8)      // 리스트 인셋 만큼 보정
                                .background(Color(.systemBackground))
                        ) {
                            ForEach(otherTasks) { task in
                                //taskRow(task)
                                taskRow(
                                    task,
                                    taskToEdit: $taskToEdit,
                                    editedTitle: $editedTitle,
                                    showEditAlert: $showEditAlert,
                                    taskToDelete: $taskToDelete,
                                    showDeleteAlert: $showDeleteAlert
                                )
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)            // 리스트 배경 투명
                    .padding(.horizontal, -4)                    // 좌우 살짝 붙이기(선택)
                    .animation(.default, value: todayTasks.count)
                    .simultaneousGesture(TapGesture().onEnded {
                        UIApplication.shared.endEditing()   // 20250422 아무데나 탭하면 키보드 내려가도록 하는 처리용
                    })
                    
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
        .alert(todayLimitMessage, isPresented: $showTodayLimitAlert) {
            Button("확인", role: .cancel) { }
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
    
    // 20250420 오늘의할일 기능 추가
    // MARK: - 공통 셀 UI (Today·Normal 공유)
    private func taskRow(
        _ task: TaskEntity,
        taskToEdit: Binding<TaskEntity?>,
        editedTitle: Binding<String>,
        showEditAlert: Binding<Bool>,
        taskToDelete: Binding<TaskEntity?>,
        showDeleteAlert: Binding<Bool>
    ) -> some View {
        // Wrapping in a plain view makes swipeActions behave correctly
        VStack {
            HStack {
                Button { toggleTask(task) } label: {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(task.isCompleted ? task.reward.color : .gray)
                        .onTapGesture {
                            toggleTask(task)  // ✅ 여기만 반응하게
                        }
                }
                Image(systemName: task.taskType.icon)
                    .foregroundColor(task.taskType.color)
                Text(task.safeTitle)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .gray : task.reward.color)
                Spacer()
            }
        }
        .contentShape(Rectangle()) // ⬅️ 이거 매우 중요! 전체 행을 터치 영역으로 지정
        .swipeActions(edge: .leading) {
            Button {
                toggleToday(task)
            } label: {
                Label(task.isToday ? "해제" : "오늘", systemImage: task.isToday ? "xmark" : "trophy")
            }.tint(task.isToday ? .pink : .teal)
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
    
    @MainActor
    private func toggleTask(_ task: TaskEntity) {
        task.isCompleted.toggle()
        task.completedAt = task.isCompleted ? Date() : nil

        let basePoint = task.reward.pointValue
        var earned = 0

        let expired = !(task.todayExpires.map { Date() < $0 } ?? false)
        
        if task.isCompleted {
           
            // ── 완료 시 ────────────────────────────────
            var multiplier = 1
            // ▸ 오늘 큐 + 만료 이전 + 아직 보너스 미지급 → 2배
            if task.isToday,
               let exp = task.todayExpires,
               Date() < exp,
               task.bonusGranted == false {
                multiplier = 2
                task.bonusGranted = true   // 중복 지급 방지
            }

            earned = basePoint * multiplier
            user.points += Int32(earned)
            totalPoints += earned

            // ▸ 완료하면 오늘 큐 해제
            task.isToday = false
            if expired {
                task.todayAssignedAt = nil
            }
        } else {

            // ── 체크 해제(완료 취소) ────────────────────
            earned = basePoint * (task.bonusGranted ? 2 : 1)
            task.bonusGranted = false

            let newPointTotal = max(Int(user.points) - earned, 0)
            user.points = Int32(newPointTotal)
            totalPoints = max(totalPoints - earned, 0)
                
            // 만약 아직 만료되지 않은 "오늘의 할 일"이면 → 다시 되살림
            if !expired {
                task.isToday = true
                if task.todayAssignedAt == nil {
                    task.todayAssignedAt = Date()
                }
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
