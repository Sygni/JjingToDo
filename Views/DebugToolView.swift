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
    @State private var exportURLs: [URL] = []
    @State private var showExportPicker = false

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
                        let urls = buildExportURLs()
                        if !urls.isEmpty {
                            exportURLs = urls
                            showExportPicker = true
                        }
                    }
                    .sheet(isPresented: $showExportPicker) {
                        DocumentExporter(urls: exportURLs, isPresented: $showExportPicker)
                            .ignoresSafeArea()
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
                allowsMultipleSelection: true   // 여러 파일 한꺼번에 선택 가능
            ) { result in
                guard let selectedFiles = try? result.get() else { return }

                // startAccessingSecurityScopedResource 반환값에 관계없이 호출
                // (Mac Catalyst에서 false를 반환해도 파일은 실제로 접근 가능한 경우 있음)
                selectedFiles.forEach { _ = $0.startAccessingSecurityScopedResource() }
                defer { selectedFiles.forEach { $0.stopAccessingSecurityScopedResource() } }

                if importEntityType == nil {
                    // 파일명으로 entity 자동 판별해서 전체 복원
                    CSVManager.importAllCSVFromDocuments(urls: selectedFiles, context: viewContext)
                } else {
                    for fileURL in selectedFiles {
                        switch importEntityType {
                        case "TaskEntity":
                            CSVManager.importCSV(url: fileURL, into: TaskEntity.self, context: viewContext)
                        case "RewardEntity":
                            CSVManager.importCSV(url: fileURL, into: RewardEntity.self, context: viewContext)
                        case "UserEntity":
                            CSVManager.importUserFromCSV(url: fileURL, context: viewContext)
                        case "Book":
                            CSVManager.importCSV(url: fileURL, into: Book.self, context: viewContext)
                        default:
                            break
                        }
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    refreshTrigger = UUID()
                }
            }

        }
    }

    /// 임시 폴더에 CSV 생성 후 URL 목록 반환 (문서 피커에 넘김)
    private func buildExportURLs() -> [URL] {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("JjingToDo_backup_\(Int(Date().timeIntervalSince1970))", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

        let exports: [(String, String)] = [
            ("TaskEntity", "tasks"),
            ("RewardEntity", "rewards"),
            ("UserEntity", "user"),
            ("ChallengeEntity", "challenges"),
            ("Book", "books")
        ]
        return exports.compactMap {
            CSVManager.exportEntityToCSV(entityName: $0.0, filename: $0.1, to: tmp, context: viewContext)
        }
    }

    private func exportAllToDocuments() {
        _ = CSVManager.exportEntityToCSVToDocuments(entityName: "TaskEntity", filename: "tasks", context: viewContext)
        _ = CSVManager.exportEntityToCSVToDocuments(entityName: "RewardEntity", filename: "rewards", context: viewContext)
        _ = CSVManager.exportEntityToCSVToDocuments(entityName: "UserEntity", filename: "user", context: viewContext)
        _ = CSVManager.exportEntityToCSVToDocuments(entityName: "ChallengeEntity", filename: "challenges", context: viewContext)
        _ = CSVManager.exportEntityToCSVToDocuments(entityName: "Book", filename: "books", context: viewContext)
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

// MARK: - Document Exporter (UIDocumentPickerViewController 래퍼)
struct DocumentExporter: UIViewControllerRepresentable {
    let urls: [URL]
    @Binding var isPresented: Bool

    func makeCoordinator() -> Coordinator { Coordinator(isPresented: $isPresented) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: urls, asCopy: true)
        picker.delegate = context.coordinator
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        @Binding var isPresented: Bool
        init(isPresented: Binding<Bool>) { _isPresented = isPresented }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { isPresented = false }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { isPresented = false }
    }
}

#if DEBUG
struct DebugToolView_Previews: PreviewProvider {
    static var previews: some View {
        DebugToolView(refreshTrigger: .constant(UUID())).environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
#endif
