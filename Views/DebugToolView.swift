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

    // 독서 탭 — 책등 표지 색
    @AppStorage("spineUsesCoverColor") private var spineUsesCoverColor = true
    @State private var isBackfillingCovers = false
    @State private var backfillStatus: String? = nil

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
                        showImportPicker = true
                    }
                    .background(
                        ImportPickerPresenter(isPresented: $showImportPicker) { urls in
                            urls.forEach { _ = $0.startAccessingSecurityScopedResource() }
                            defer { urls.forEach { $0.stopAccessingSecurityScopedResource() } }
                            CSVManager.importAllCSVFromDocuments(urls: urls, context: viewContext)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                refreshTrigger = UUID()
                            }
                        }
                    )
                }

                Section(header: Text("📚 독서 탭")) {
                    Toggle("책등에 표지 색 반영", isOn: $spineUsesCoverColor)

                    Button {
                        backfillCovers()
                    } label: {
                        HStack {
                            Text("📕 책 표지 일괄 가져오기")
                            if isBackfillingCovers { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(isBackfillingCovers)

                    if let status = backfillStatus {
                        Text(status)
                            .font(.footnote)
                            .foregroundColor(.gray)
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
        }
    }

    /// coverURL 없는 책들을 제목으로 재검색해서 표지 URL 채우기
    private func backfillCovers() {
        isBackfillingCovers = true
        backfillStatus = nil

        _Concurrency.Task { @MainActor in
            let req = NSFetchRequest<Book>(entityName: "Book")
            let books = (try? viewContext.fetch(req)) ?? []
            let targets = books.filter { ($0.coverURL ?? "").isEmpty && !($0.title ?? "").isEmpty }

            guard !targets.isEmpty else {
                backfillStatus = "표지가 없는 책이 없습니다."
                isBackfillingCovers = false
                return
            }

            let service = MultiSourceSearchService()
            var found = 0

            for (idx, book) in targets.enumerated() {
                backfillStatus = "검색 중... (\(idx + 1)/\(targets.count))"
                let title = (book.title ?? "").trimmingCharacters(in: .whitespaces)
                let results = (try? await service.search(query: title)) ?? []

                let lowTitle = title.lowercased()
                // 제목이 정확히 일치하는 결과 우선, 없으면 표지가 있는 첫 결과
                let best = results.first { $0.coverURL != nil && $0.title.lowercased() == lowTitle }
                    ?? results.first { $0.coverURL != nil }

                if let url = best?.coverURL {
                    book.coverURL = url.absoluteString
                    found += 1
                }

                // API 연속 호출 부담 완화
                try? await _Concurrency.Task.sleep(nanoseconds: 300_000_000)
            }

            try? viewContext.save()
            backfillStatus = "완료: \(found)/\(targets.count)권 표지 저장됨"
            isBackfillingCovers = false
            refreshTrigger = UUID()
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

// MARK: - Import Picker Presenter
// .sheet 없이 UIKit에서 직접 present — Mac Catalyst에서 sheet 루프 방지
struct ImportPickerPresenter: UIViewRepresentable {
    @Binding var isPresented: Bool
    let onPick: ([URL]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UIView { UIView() }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard isPresented, context.coordinator.picker == nil else { return }
        let types: [UTType] = [.commaSeparatedText, .text, .plainText]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.shouldShowFileExtensions = true
        picker.delegate = context.coordinator
        context.coordinator.picker = picker
        DispatchQueue.main.async {
            uiView.window?.rootViewController?.present(picker, animated: true)
        }
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: ImportPickerPresenter
        var picker: UIDocumentPickerViewController?
        init(_ parent: ImportPickerPresenter) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onPick(urls)
            finish()
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { finish() }

        private func finish() {
            picker = nil
            DispatchQueue.main.async { self.parent.isPresented = false }
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
