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
    @Environment(\.colorScheme) private var colorScheme
    
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
    @State private var editedDueDate: Date? = nil
    @State private var editedRewardLevel: RewardLevel = .easy
    @State private var editedTaskType: TaskType = .personal
    @State private var showEditSheet = false
    @State private var showEditDueDatePicker = false
    
    // 20250420 오늘의할일 기능 추가
    @State /*private*/ var showTodayLimitAlert = false
    @State /*private*/ var todayLimitMessage = ""
    @State /*private*/ var listRefreshToken: Int = 0  // @FetchRequest가 속성 변경을 놓칠 때 강제 갱신용
    
    // 20250423 투두리스트에 타입 필터 추가
    @State /*private*/ var selectedFilterType: TaskType? = nil  // 전체(default nil), 개인/공부
    @State /*private*/ var questSortOrder: QuestSortOrder = .createdDesc

    // Due date
    @State private var showDueDatePicker: Bool = false
    @State private var newTaskDueDate: Date? = nil

    // 정원
    @FetchRequest(entity: ChugumiActionEntity.entity(), sortDescriptors: [])
    private var mossActions: FetchedResults<ChugumiActionEntity>
    @State private var showGarden = false

    // 완료 피드백
    @State private var showEarnedPop = false
    @State private var lastEarned = 0
    @State private var lastMultiplier = 1
    @State private var lastWasAuto = false
    
    let taskKey = "savedTasks"
    let pointKey = "savedPoints"
    let totalPointKey = "savedTotalPoints"
    
    init(user: UserEntity) {
        self.user = user

        // 헤더 배경 투명하게 만들기
        /*UITableViewHeaderFooterView.appearance().backgroundView = {
            let view = UIView()
            view.backgroundColor = .clear
            return view
        }()
         */
        
        
        let appearance = UITableView.appearance()
        appearance.backgroundColor = .clear
        appearance.separatorStyle = .none
        appearance.sectionHeaderTopPadding = 0
        appearance.sectionHeaderHeight = 0  // 추가!
        
        let headerFooterAppearance = UITableViewHeaderFooterView.appearance()
        headerFooterAppearance.tintColor = .clear
        headerFooterAppearance.backgroundView = {
            let view = UIView()
            view.backgroundColor = .clear
            return view
        }()
    }
    
    var sortedTaskEntities: [TaskEntity] {
        let incomplete = taskEntities.filter { !$0.isCompleted }
            .sorted(by: { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) })
        
        let complete = taskEntities.filter { $0.isCompleted }
            .sorted(by: { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) })
        
        return incomplete + complete
    }
    
    var body: some View {
        let _ = listRefreshToken  // SwiftUI 의존성 추적 강제 등록
        return ZStack {
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
                                        editedDueDate: $editedDueDate,
                                        showEditSheet: $showEditSheet,
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
                                //.background(Color(.systemBackground))     // 20250427 이렇게 하면 다크모드일 때 백그라운드에 Black 배경 생김 -> 투명하게 만들기 위해 Color.clear로 수정
                                .background(Color.clear)
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
                                    
                                    HStack(spacing: 6) {
                                        Picker("필터", selection: $selectedFilterType) {
                                            Text("전체").tag(nil as TaskType?)
                                            ForEach(TaskType.allCases, id: \.self) { type in
                                                Text(type.label).tag(type as TaskType?)
                                            }
                                        }
                                        .pickerStyle(SegmentedPickerStyle())

                                        Menu {
                                            ForEach(QuestSortOrder.allCases, id: \.self) { order in
                                                Button {
                                                    questSortOrder = order
                                                } label: {
                                                    Label(order.label, systemImage: questSortOrder == order ? "checkmark" : order.icon)
                                                }
                                            }
                                        } label: {
                                            Image(systemName: "arrow.up.arrow.down")
                                                .foregroundColor(.secondary)
                                                .frame(width: 28, height: 28)
                                        }
                                    }
                                    //.padding(.bottom, 8)
                                    Divider()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.accentColor)
                                }
                                .padding(.top, 6)
                                .padding(.leading, -8)      // 리스트 인셋 만큼 보정
                                //.background(Color(.systemBackground))     // 20250427 이렇게 하면 다크모드일 때 백그라운드에 Black 배경 생김 -> 투명하게 만들기 위해 Color.clear로 수정
                                .background(Color.clear)
                        ) {
                            ForEach(otherTasks) { task in
                                //taskRow(task)
                                taskRow(
                                    task,
                                    taskToEdit: $taskToEdit,
                                    editedTitle: $editedTitle,
                                    editedDueDate: $editedDueDate,
                                    showEditSheet: $showEditSheet,
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
                .sheet(isPresented: $showEditSheet) {
                    editSheet
                }
                .sheet(isPresented: $showGarden) {
                    GardenView()
                }
                .padding()

                Spacer()
            }
        }        
        .overlay(alignment: .top) {
            if showEarnedPop {
                earnedPop
                    .padding(.top, 76)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.6), value: showEarnedPop)
        .onChange(of: showEarnedPop) { _, shown in
            guard shown else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { showEarnedPop = false }
        }
        .alert(todayLimitMessage, isPresented: $showTodayLimitAlert) {
            Button("확인", role: .cancel) { }
        }
        
    }

    // 20250327 MARK: - View Components
    /// 완료 순간 피드백 — 배수를 받았다면 그 사실을 눈에 보이게
    private var earnedPop: some View {
        VStack(spacing: 4) {
            Text("+\(lastEarned) 💎")
                .font(.title2.bold())
                .foregroundColor(Color(hex: "#3E9B6E"))
            if lastMultiplier > 1 {
                Text(lastWasAuto ? "🎲 랜덤 미션 ×3" : "🏆 오늘의 미션 ×2")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color(hex: "#C0562F"))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }

    /// 등급 + 연속 + 오늘의 화분. 탭하면 정원 전체가 열린다.
    private func headerSection(points: Int32, totalPoints: Int, viewContext: NSManagedObjectContext) -> some View {
        let all = Array(taskEntities)
        let rank = GardenRank.make(planted: GardenStats.plantedCount(tasks: all))
        let streak = GardenStats.streak(tasks: all)
        let todayKey = GardenStats.today
        let today = GardenStats.build(tasks: all, moss: Array(mossActions))[todayKey]
            ?? DayGarden(date: todayKey, plants: [], moss: 0)

        return Button {
            showGarden = true
        } label: {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    DayPotView(day: today)
                        .frame(width: 54, height: 62)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text(rank.title)
                                .font(.subheadline.weight(.semibold))
                            Text("\(rank.stage)단계")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            if streak.current > 0 {
                                Label("\(streak.current)일", systemImage: "flame.fill")
                                    .font(.caption)
                                    .foregroundColor(Color(hex: "#E2703A"))
                            }
                        }
                        ProgressView(value: rank.progress)
                            .tint(Color(hex: "#3E9B6E"))
                        HStack {
                            Text("심은 식물 \(rank.planted)그루")
                            Spacer()
                            Text("다음까지 \(rank.remaining)")
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 6) {
                    Text("💎 \(user.points)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if today.count > 0 {
                        Text("· 오늘 \(today.count)그루")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// 세그먼트 피커(UISegmentedControl)는 foregroundColor를 무시하므로
    /// 이미지 자체에 색을 입혀 alwaysOriginal로 넘긴다. 기본 라벨색은 너무 진하다.
    private func categoryIcon(_ type: TaskType) -> Image {
        let tint = UIColor(white: colorScheme == .dark ? 0.74 : 0.46, alpha: 1)
        let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        guard let base = UIImage(systemName: type.icon, withConfiguration: config) else {
            return Image(systemName: type.icon)
        }
        return Image(uiImage: base.withTintColor(tint, renderingMode: .alwaysOriginal))
    }

    /// 입력줄에 들어가는 마감일 토글 — 날짜를 고르면 버튼에 그대로 표시된다
    private var dueDateButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showDueDatePicker.toggle()
                // 피커를 열면 기본값(오늘)을 실제 값으로 반영, 닫으면 해제
                newTaskDueDate = showDueDatePicker ? (newTaskDueDate ?? Date()) : nil
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: newTaskDueDate != nil ? "calendar.badge.checkmark" : "calendar")
                    .font(.system(size: 14))
                if let due = newTaskDueDate {
                    Text(dueDateDisplay(due)).font(.caption2)
                }
            }
            .foregroundColor(newTaskDueDate != nil ? Color(hex: "#3E9B6E") : .secondary)
            .padding(.horizontal, newTaskDueDate != nil ? 9 : 11)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(newTaskDueDate != nil
                          ? Color(hex: "#3E9B6E").opacity(0.12)
                          : Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }

    private func inputSection(newTask: Binding<String>, viewContext: NSManagedObjectContext, selectedRewardLevel: RewardLevel, saveContext: @escaping () -> Void) ->  some View {
        let canAdd = !newTask.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty

        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                TextField("할 일을 입력하세요", text: newTask)
                    .submitLabel(.done)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                dueDateButton

                Button {
                    guard canAdd else { return }
                    let task = TaskEntity(context: viewContext)
                    task.id = UUID()
                    task.title = newTask.wrappedValue.trimmingCharacters(in: .whitespaces)
                    task.isCompleted = false
                    task.createdAt = Date()
                    task.rewardLevelRaw = Int16(selectedRewardLevel.rawValue)
                    task.taskType = selectedTaskType
                    task.dueDate = newTaskDueDate

                    newTask.wrappedValue = ""
                    newTaskDueDate = nil
                    showDueDatePicker = false
                    saveContext()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(
                            Circle().fill(canAdd ? Color(hex: "#3E9B6E") : Color.secondary.opacity(0.3))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canAdd)
                .animation(.easeInOut(duration: 0.15), value: canAdd)
            }

            // 난이도(심을 식물) + 카테고리를 한 줄에
            HStack(spacing: 8) {
                Picker("난이도", selection: $selectedRewardLevel) {
                    ForEach(RewardLevel.allCases, id: \.self) { level in
                        Text(level.label).tag(level)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(maxWidth: .infinity)

                Picker("타입", selection: $selectedTaskType) {
                    ForEach(TaskType.allCases, id: \.self) { type in
                        categoryIcon(type).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 108)
            }

            if showDueDatePicker {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { newTaskDueDate ?? Date() },
                        set: { newTaskDueDate = $0 }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .frame(maxHeight: 320)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(Color(.systemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 0.5)
        )
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
    
    /// 오늘이거나 지난 마감 — 알약 배경으로 강조
    private func dueIsUrgent(_ date: Date, isCompleted: Bool) -> Bool {
        guard !isCompleted else { return false }
        let cal = Calendar.current
        let days = cal.dateComponents([.day],
                                      from: cal.startOfDay(for: Date()),
                                      to: cal.startOfDay(for: date)).day ?? 0
        return days <= 0
    }

    private func dueDateColor(_ date: Date, isCompleted: Bool) -> Color {
        if isCompleted { return .secondary }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dueDay = cal.startOfDay(for: date)
        let days = cal.dateComponents([.day], from: today, to: dueDay).day ?? 0
        if days <= 0 { return .red }
        if days <= 2 { return .yellow }
        return .secondary
    }

    private func dueDateDisplay(_ date: Date) -> String {
        let cal = Calendar.current
        let symbols = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
        let weekday = cal.component(.weekday, from: date) - 1
        let month = cal.component(.month, from: date)
        let day = cal.component(.day, from: date)
        return "\(month)/\(day)(\(symbols[weekday]))"
    }

    // MARK: - Edit Sheet
    @ViewBuilder
    private var editSheet: some View {
        NavigationView {
            Form {
                Section("제목") {
                    TextField("할 일", text: $editedTitle)
                }
                Section("카테고리") {
                    Picker("카테고리", selection: $editedTaskType) {
                        ForEach(TaskType.allCases, id: \.self) { type in
                            Label(type.label, systemImage: type.icon).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("난이도") {
                    Picker("난이도", selection: $editedRewardLevel) {
                        Text(RewardLevel.easy.label).tag(RewardLevel.easy)
                        Text(RewardLevel.normal.label).tag(RewardLevel.normal)
                        Text(RewardLevel.hard.label).tag(RewardLevel.hard)
                        Text(RewardLevel.veryHard.label).tag(RewardLevel.veryHard)
                    }
                    .pickerStyle(.segmented)
                }
                Section("마감일") {
                    if editedDueDate != nil {
                        DatePicker(
                            "날짜",
                            selection: Binding(
                                get: { editedDueDate ?? Date() },
                                set: { editedDueDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                        Button("날짜 삭제", role: .destructive) {
                            editedDueDate = nil
                        }
                    } else {
                        Button("날짜 추가") {
                            editedDueDate = Date()
                        }
                    }
                }
            }
            .navigationTitle("할 일 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { showEditSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        if let task = taskToEdit {
                            task.title = editedTitle
                            task.dueDate = editedDueDate
                            task.rewardLevelRaw = Int16(editedRewardLevel.rawValue)
                            task.taskType = editedTaskType
                            saveContext()
                            listRefreshToken += 1
                        }
                        showEditSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - 공통 셀 UI (Today·Normal 공유)
    private func taskRow(
        _ task: TaskEntity,
        taskToEdit: Binding<TaskEntity?>,
        editedTitle: Binding<String>,
        editedDueDate: Binding<Date?>,
        showEditSheet: Binding<Bool>,
        taskToDelete: Binding<TaskEntity?>,
        showDeleteAlert: Binding<Bool>
    ) -> some View {
        // Wrapping in a plain view makes swipeActions behave correctly
        VStack {
            HStack(spacing: 10) {
                Button { toggleTask(task) } label: {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(task.isCompleted ? task.reward.color : Color.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)    // ✅ 버튼 눌렀을 때 깜빡이는 효과 없애기 (있으면 거슬림)

                // 난이도 = 정원에 심길 식물. 글자색 대신 이 배지가 난이도를 나타낸다
                Text(task.reward.label)
                    .font(.system(size: 13))
                    .frame(width: 26, height: 26)
                    .background(
                        Circle().fill(task.reward.color.opacity(task.isCompleted ? 0.07 : 0.16))
                    )
                    .opacity(task.isCompleted ? 0.5 : 1)

                Text(task.safeTitle)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                    .lineLimit(2)

                Spacer(minLength: 4)

                if task.isToday && task.isAutoAssigned {
                    Text("🎲").font(.caption2)
                }

                if let due = task.dueDate {
                    Text(dueDateDisplay(due))
                        .font(.caption2)
                        .fontWeight(dueIsUrgent(due, isCompleted: task.isCompleted) ? .semibold : .regular)
                        .foregroundColor(dueDateColor(due, isCompleted: task.isCompleted))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(
                                dueIsUrgent(due, isCompleted: task.isCompleted)
                                ? dueDateColor(due, isCompleted: task.isCompleted).opacity(0.13)
                                : Color.clear
                            )
                        )
                }

                // 카테고리는 항상 맨 끝 — 마감일 유무와 상관없이 오른쪽 정렬이 유지된다
                Image(systemName: task.taskType.icon)
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(task.isCompleted ? 0.4 : 0.7))
                    .frame(width: 16)
            }
            .padding(.vertical, 2)
        }
        .contentShape(Rectangle()) // ⬅️ 이거 매우 중요! 전체 행을 터치 영역으로 지정
        .swipeActions(edge: .leading) {
            if !task.isCompleted {
                Button {
                    toggleToday(task)
                } label: {
                    Label(task.isToday ? "해제" : "오늘", systemImage: task.isToday ? "xmark" : "trophy")
                }.tint(task.isToday ? .pink : .teal)
            }
        }
        .swipeActions(edge: .trailing) {
             Button {
                 taskToEdit.wrappedValue = task
                 editedTitle.wrappedValue = task.safeTitle
                 editedDueDate.wrappedValue = task.dueDate
                 editedRewardLevel = RewardLevel(rawValue: Int(task.rewardLevelRaw)) ?? .easy
                 editedTaskType = task.taskType
                 showEditSheet.wrappedValue = true
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
            // ▸ 오늘 큐 + 만료 이전 + 아직 보너스 미지급 → 자동배정 3배, 수동 2배
            if task.isToday,
               let exp = task.todayExpires,
               Date() < exp,
               task.bonusGranted == false {
                multiplier = task.isAutoAssigned ? 3 : 2
                task.bonusGranted = true
            }

            // ▸ 연속 보너스 — 챌린지와 같은 공식(+연속×10)
            let streakBefore = GardenStats.streak(tasks: Array(taskEntities)).current
            let streakBonus = min(streakBefore, 30) * 10

            earned = basePoint * multiplier + streakBonus
            user.points += Int32(earned)
            user.lifetimePoints += Int64(earned)   // 써도 줄지 않는 누적 기록
            totalPoints += earned
            lastEarned = earned
            lastMultiplier = multiplier
            lastWasAuto = task.isAutoAssigned
            showEarnedPop = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            // ▸ 완료하면 오늘 큐 해제
            task.isToday = false
            if expired {
                task.todayAssignedAt = nil
            }
        } else {

            // ── 체크 해제(완료 취소) ────────────────────
            let bonusMultiplier = task.bonusGranted ? (task.isAutoAssigned ? 3 : 2) : 1
            earned = basePoint * bonusMultiplier
            task.bonusGranted = false

            let newPointTotal = max(Int(user.points) - earned, 0)
            user.points = Int32(newPointTotal)
            user.lifetimePoints = max(0, user.lifetimePoints - Int64(earned))
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
