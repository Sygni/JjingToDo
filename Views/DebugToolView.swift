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
                    Button("📤 CSV 백업 (Task + Reward)") {
                        exportAllToDocuments()
                        showExportConfirmation = true
                    }
                    .alert(isPresented: $showExportConfirmation) {
                        Alert(
                            title: Text("백업 완료"),
                            message: Text("tasks.csv 와 rewards.csv 파일이 파일 앱에 저장되었습니다."),
                            dismissButton: .default(Text("확인"))
                        )
                    }

                    Button("📥 CSV 불러오기 (Task)") {
                        importEntityType = "TaskEntity"
                        showImportPicker = true
                    }

                    Button("📥 CSV 불러오기 (Reward)") {
                        importEntityType = "RewardEntity"
                        showImportPicker = true
                    }
                }

                Section {
                    Text(versionString)
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("디버그 툴")
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [UTType.text, UTType.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                do {
                    guard let selectedFile: URL = try result.get().first,
                          let entityType = importEntityType else { return }
                    
                    /*
                    if entityType == "TaskEntity" {
                        importTasksFromCSV(url: selectedFile)
                    } else if entityType == "RewardEntity" {
                        importRewardsFromCSV(url: selectedFile)
                    }
                    */
                    if entityType == "TaskEntity" {
                        importCSV(url: selectedFile, into: TaskEntity.self)
                    } else if entityType == "RewardEntity" {
                        importCSV(url: selectedFile, into: RewardEntity.self)
                    }
                    refreshTrigger = UUID()
                } catch {
                    print("❌ 파일 가져오기 실패: \(error.localizedDescription)")
                }
            }
        }
    }

    private func exportAllToDocuments() {
        _ = exportEntityToCSVToDocuments(entityName: "TaskEntity", filename: "tasks", context: viewContext)
        _ = exportEntityToCSVToDocuments(entityName: "RewardEntity", filename: "rewards", context: viewContext)
        print("✅ CSV 백업 완료 (Document 디렉토리)")
    }

    private func exportEntityToCSVToDocuments(entityName: String, filename: String, context: NSManagedObjectContext) -> URL? {
        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) else { return nil }

        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        do {
            let objects = try context.fetch(fetchRequest)
            let attributeNames = entity.attributesByName.keys.sorted()

            var csvString = attributeNames.joined(separator: ",") + "\n"

            for object in objects {
                let values = attributeNames.map { key -> String in
                    if let value = object.value(forKey: key) {
                        return "\"\(value)\""
                    } else {
                        return "\"\""
                    }
                }
                csvString += values.joined(separator: ",") + "\n"
            }

            let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = docURL.appendingPathComponent("\(filename).csv")
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Export error: \(error)")
            return nil
        }
    }

    private func importCSV<T: NSManagedObject>(url: URL, into entityType: T.Type) {
            do {
                let content = try String(contentsOf: url)
                let rows = content.components(separatedBy: "\n").filter { !$0.isEmpty }
                guard rows.count > 1 else { return }
                let keys = rows[0].components(separatedBy: ",")

                for row in rows.dropFirst() {
                    let values = row.components(separatedBy: ",").map { $0.replacingOccurrences(of: "\"", with: "") }
                    let object = T(context: viewContext)
                    let attributes = T.entity().attributesByName

                    for (index, key) in keys.enumerated() where index < values.count {
                        let value = values[index]
                        guard let attribute = attributes[key] else { continue }

                        switch attribute.attributeType {
                        case .UUIDAttributeType:
                            object.setValue(UUID(uuidString: value), forKey: key)
                        case .dateAttributeType:
                            let formatter = ISO8601DateFormatter()
                            object.setValue(formatter.date(from: value), forKey: key)
                        case .integer32AttributeType:
                            object.setValue(Int32(value) ?? 0, forKey: key)
                        case .booleanAttributeType:
                            object.setValue(value == "1" || value.lowercased() == "true", forKey: key)
                        case .stringAttributeType:
                            object.setValue(value, forKey: key)
                        default:
                            print("⚠️ 처리되지 않은 속성 타입: \(attribute.attributeType) for key: \(key)")
                        }
                    }
                }
                try viewContext.save()
                print("✅ \(T.self) CSV 가져오기 완료")
            } catch {
                print("❌ CSV 파싱 실패: \(error.localizedDescription)")
            }
        }
/*
    private func importTasksFromCSV(url: URL) {
        do {
            let content = try String(contentsOf: url)
            let rows = content.components(separatedBy: "\n").filter { !$0.isEmpty }
            guard rows.count > 1 else { return }
            let keys = rows[0].components(separatedBy: ",")

            for row in rows.dropFirst() {
                let values = row.components(separatedBy: ",").map { $0.replacingOccurrences(of: "\"", with: "") }
                let task = TaskEntity(context: viewContext)
                for (index, key) in keys.enumerated() where index < values.count {
                    let value = values[index]
                    if let attribute = TaskEntity.entity().attributesByName[key] {
                        switch attribute.attributeType {
                        case .UUIDAttributeType:
                            task.setValue(UUID(uuidString: value), forKey: key)
                        case .dateAttributeType:
                            let formatter = ISO8601DateFormatter()
                            task.setValue(formatter.date(from: value), forKey: key)
                        case .integer32AttributeType:
                            task.setValue(Int32(value), forKey: key)
                        case .booleanAttributeType:
                            task.setValue(value == "1" || value.lowercased() == "true", forKey: key)
                        default:
                            task.setValue(value, forKey: key)
                        }
                    }
                }
            }
            try viewContext.save()
            print("✅ Task CSV 가져오기 완료")
        } catch {
            print("❌ Task CSV 파싱 실패: \(error.localizedDescription)")
        }
    }

    private func importRewardsFromCSV(url: URL) {
        do {
            let content = try String(contentsOf: url)
            let rows = content.components(separatedBy: "\n").filter { !$0.isEmpty }
            guard rows.count > 1 else { return }
            let keys = rows[0].components(separatedBy: ",")

            for row in rows.dropFirst() {
                let values = row.components(separatedBy: ",").map { $0.replacingOccurrences(of: "\"", with: "") }
                let reward = RewardEntity(context: viewContext)
                for (index, key) in keys.enumerated() where index < values.count {
                    let value = values[index]
                    if let attribute = RewardEntity.entity().attributesByName[key] {
                        switch attribute.attributeType {
                        case .UUIDAttributeType:
                            reward.setValue(UUID(uuidString: value), forKey: key)
                        case .dateAttributeType:
                            let formatter = ISO8601DateFormatter()
                            reward.setValue(formatter.date(from: value), forKey: key)
                        case .integer32AttributeType:
                            reward.setValue(Int32(value), forKey: key)
                        case .booleanAttributeType:
                            reward.setValue(value == "1" || value.lowercased() == "true", forKey: key)
                        default:
                            reward.setValue(value, forKey: key)
                        }
                    }
                }
            }
            try viewContext.save()
            print("✅ Reward CSV 가져오기 완료")
        } catch {
            print("❌ Reward CSV 파싱 실패: \(error.localizedDescription)")
        }
    }
*/
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
