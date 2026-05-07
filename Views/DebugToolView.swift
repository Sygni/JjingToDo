//
//  Untitled.swift
//  JjingToDo
//
//  Created by Jeongah Seo on 3/29/25.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers
import UIKit

struct DebugToolView: View {
    @Binding var refreshTrigger: UUID   // 20250328 Debug View 리프레시용

    @Environment(\.managedObjectContext) private var viewContext
    @State private var showExportConfirmation = false
    @State private var showImportPicker = false
    @State private var importEntityType: String? = nil

    var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "버전 \(version) (\(build))"
    }

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("💣 전체 리셋")) {
                    Button("모든 데이터 삭제") {
                        resetAllData()
                        refreshTrigger = UUID() // 트리거 변경 → 뷰 리렌더링
                    }
                    .foregroundColor(.red)
                }

                Section(header: Text("🧪 테스트용 설정")) {
                    Button("포인트 10000으로 설정") {
                        setPoints(to: 10000)
                        refreshTrigger = UUID() // 트리거 변경 → 뷰 리렌더링
                    }

                    Button("보상 더미 추가") {
                        addDummyReward()
                        refreshTrigger = UUID() // 트리거 변경 → 뷰 리렌더링
                    }

                    Button("태스크 전체 삭제") {
                        deleteAllTasks()
                        refreshTrigger = UUID() // 트리거 변경 → 뷰 리렌더링
                    }
                }

                Section(header: Text("📦 백업 및 복원")) {
                    Button("📤 CSV 백업(All Data)") {
                        exportAllToDocuments()
                        showExportConfirmation = true
                    }
                    .alert(isPresented: $showExportConfirmation) {
                        Alert(
                            title: Text("백업 완료"),
                            message: Text("Task, Reward, User, Challenge, Book 데이터가 Files에 저장되었습니다."),
                            dismissButton: .default(Text("확인"))
                        )
                    }

                    Button("📥 CSV 불러오기") {
                        //CSVManager.importAllCSVFromDocuments(context: viewContext)
                        importEntityType = nil  // ✅ 전체 불러오기용 시그널
                        showImportPicker = true
                        //refreshTrigger = UUID()
                    }
                }

                Section(header: Text("📖 가이드")) {
                    NavigationLink(destination: PointGuideView()) {
                        Label("포인트 가이드", systemImage: "star.circle")
                    }
                }

                Section {
                    Text(versionString)
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("설정")
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [UTType.text, UTType.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                do {
                    let selectedFiles = try result.get()
                    
                    for fileURL in selectedFiles {
                        print("📄 선택한 파일 URL: \(fileURL)")
                        print("📄 경로 접근 가능? \(FileManager.default.isReadableFile(atPath: fileURL.path))")
                        
                        if fileURL.startAccessingSecurityScopedResource() {
                            defer { fileURL.stopAccessingSecurityScopedResource() }
                            
                            //guard let entityType = importEntityType else { return }
                            
                            guard let entityType = importEntityType else {
                                print("📦 entityType이 nil → 전체 CSV 불러오기 수행")
                                CSVManager.importAllCSVFromDocuments(urls: selectedFiles, context: viewContext)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    refreshTrigger = UUID()   // ✅ 살짝 딜레이로 리스트 안전하게 갱신
                                }
                                return
                            }
                            
                            switch entityType {
                            case "TaskEntity":
                                CSVManager.importCSV(url: fileURL, into: TaskEntity.self, context: viewContext)
                            case "RewardEntity":
                                CSVManager.importCSV(url: fileURL, into: RewardEntity.self, context: viewContext)
                            case "UserEntity":
                                CSVManager.importUserFromCSV(url: fileURL, context: viewContext)
                                refreshTrigger = UUID()
                            case "Book":
                                CSVManager.importCSV(url: fileURL, into: Book.self, context: viewContext)
                            default:
                                break
                            }
                            
                            refreshTrigger = UUID()
                        } else {
                            print("❌ 보안 접근 권한 실패: \(fileURL)")
                        }
                    }
                } catch {
                    print("❌ 파일 가져오기 실패: \(error.localizedDescription)")
                }
            }

        }
    }

    private func exportAllToDocuments() {
        _ = CSVManager.exportEntityToCSVToDocuments(entityName: "TaskEntity", filename: "tasks", context: viewContext)
        _ = CSVManager.exportEntityToCSVToDocuments(entityName: "RewardEntity", filename: "rewards", context: viewContext)
        _ = CSVManager.exportEntityToCSVToDocuments(entityName: "UserEntity", filename: "user", context: viewContext)
        _ = CSVManager.exportEntityToCSVToDocuments(entityName: "ChallengeEntity", filename: "challenges", context: viewContext)
        _ = CSVManager.exportEntityToCSVToDocuments(entityName: "Book", filename: "books", context: viewContext)
        print("✅ CSV 백업 완료 (Document 디렉토리)")
    }

    private func resetAllData() {
        let userFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "UserEntity")
        let userDelete = NSBatchDeleteRequest(fetchRequest: userFetch)
        try? viewContext.execute(userDelete)

        let taskFetch: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        if let tasks = try? viewContext.fetch(taskFetch) {
            for task in tasks {
                viewContext.delete(task)
            }
        }

        let rewardFetch: NSFetchRequest<RewardEntity> = RewardEntity.fetchRequest()
        if let rewards = try? viewContext.fetch(rewardFetch) {
            for reward in rewards {
                viewContext.delete(reward)
            }
        }

        let newUser = UserEntity(context: viewContext)
        newUser.id = UUID()
        newUser.points = 0
        newUser.lifetimePoints = 0
        newUser.joinedAt = Date()

        try? viewContext.save()
        viewContext.refreshAllObjects()

        print("✅ 전체 데이터 삭제 + 포인트 초기화 + 보상 삭제 완료")
    }
    
    private func setPoints(to amount: Int32) {
        let request = UserEntity.fetchRequest()
        if let user = try? viewContext.fetch(request).first {
            user.points = amount
            try? viewContext.save()
            print("✅ 포인트 설정 완료")
        }
    }

    private func addDummyReward() {
        let reward = RewardEntity(context: viewContext)
        reward.id = UUID()
        reward.title = "테스트 보상"
        reward.pointCost = 100
        reward.remainingCount = 3
        reward.createdAt = Date()
        reward.rewardType = "기타"
        try? viewContext.save()
        print("✅ 더미 보상 추가 완료")
    }

    private func deleteAllTasks() {
        viewContext.refreshAllObjects()

        let fetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        do {
            let tasks = try viewContext.fetch(fetchRequest)
            for task in tasks {
                viewContext.delete(task)
            }
            try viewContext.save()
            print("✅ 직접 태스크 삭제 완료")
        } catch {
            print("❌ 직접 삭제 실패: \(error.localizedDescription)")
        }

        debugCheckTaskCount()
    }

    private func debugCheckTaskCount() {
        let fetchRequest = NSFetchRequest<TaskEntity>(entityName: "TaskEntity")
        do {
            let tasks = try viewContext.fetch(fetchRequest)
            print("🧪 남아있는 태스크 수: \(tasks.count)")
        } catch {
            print("❌ 태스크 fetch 실패: \(error.localizedDescription)")
        }
    }
}

#if DEBUG
struct DebugToolView_Previews: PreviewProvider {
    static var previews: some View {
        DebugToolView(refreshTrigger: .constant(UUID())).environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
#endif
