//
//  CSVManager.swift
//  JjingToDo
//
//  Created by Jeongah Seo on 4/1/25.
//

import Foundation
import CoreData

struct CSVManager {

    // MARK: - UserEntity Export
    static func exportUserToCSV(user: UserEntity) -> String {
        let csvHeader = "points,lifetimePoints\n"
        let csvRow = "\(user.points),\(user.lifetimePoints)\n"
        return csvHeader + csvRow
    }

    // MARK: - UserEntity Import
    static func importUserFromCSV(url: URL, context: NSManagedObjectContext) {
        do {
            let content = try String(contentsOf: url)
            let rows = content.components(separatedBy: "\n").filter { !$0.isEmpty }
            guard rows.count > 1 else { return }

            let keys = rows[0]
                .components(separatedBy: ",")
                .map { $0.replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespacesAndNewlines) }
            let values = rows[1]
                .components(separatedBy: ",")
                .map { $0.replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespacesAndNewlines) }
            
            // ✅ 기존 유저 전부 삭제
            let fetchRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
            let existingUsers = try context.fetch(fetchRequest)
            
            if existingUsers.count != 1 {
                print("⚠️ UserEntity 수: \(existingUsers.count) → 강제 초기화")
                //existingUsers.forEach { context.delete($0) }
                for user in existingUsers {
                    context.delete(user)
                }
                try context.save() // 삭제 후 저장
            }

            // ✅ 기존 유저가 있으면 재사용, 없으면 새로 생성
            // 🔥 삭제 후 다시 fetch
            let refreshedFetch = try context.fetch(fetchRequest)
            let user = refreshedFetch.first ?? UserEntity(context: context)
            
            for (index, key) in keys.enumerated() where index < values.count {
                let value = values[index]
                
                switch key {
                case "id":
                    if let uuid = UUID(uuidString: value) {
                        if user.id != uuid {
                            // 나 자신이 아닌, 중복된 UUID 가진 객체 있으면 제거
                            let duplicateRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
                            duplicateRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
                            let duplicates = try? context.fetch(duplicateRequest)
                            duplicates?.filter { $0 != user }.forEach { context.delete($0) }

                            user.id = uuid
                        }
                    } else {
                        print("❌ 잘못된 UUID: \(value)")
                    }
                case "joinedAt":
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
                    if let date = formatter.date(from: value) {
                        user.joinedAt = date
                    } else {
                        print("❌ 날짜 파싱 실패: \(value)")
                    }
                case "points":
                    user.points = Int32(value) ?? 0
                case "lifetimePoints":
                    user.lifetimePoints = Int64(value) ?? 0
                default:
                    print("⚠️ 매핑되지 않은 키: \(key/*cleanedKey*/)")
                    break
                }
            }

            try context.save()
            print("✅ UserEntity 복원 완료")
            
            let debug_users = try context.fetch(fetchRequest)
            print("👥 현재 UserEntity 개수: \(debug_users.count)")
            for user in debug_users {
                print("🧾 id: \(user.id.uuidString ?? "nil") | points: \(user.points) | lifetimePoints: \(user.lifetimePoints)")
            }
            
        } catch {
            print("❌ UserEntity CSV 파싱 실패: \(error.localizedDescription)")
        }
    }

    // MARK: - Generic CSV Import
    static func importCSV<T: NSManagedObject>(url: URL, into entityType: T.Type, context: NSManagedObjectContext) {
        do {
            let content = try String(contentsOf: url)
            let rows = content.components(separatedBy: "\n").filter { !$0.isEmpty }
            guard rows.count > 1 else { return }

            //let keys = rows[0].components(separatedBy: ",").map { $0.replacingOccurrences(of: "\"", with: "") }
            let keys = rows[0]
                .components(separatedBy: ",")
                .map { $0.replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespacesAndNewlines) }
            
            for row in rows.dropFirst() {
                let values = parseCSVLine(row)
                let attributes = T.entity().attributesByName
     
                //let object = T(context: context)
                // 20250519 .csv에서 복원할 때 항목 덮어쓰기 되지 않고 추가되는 이슈 수정
                // 1. UUID 먼저 찾아서 중복 여부 판단
                var object: T? = nil

                if let idIndex = keys.firstIndex(of: "id"),
                   let uuid = UUID(uuidString: values[idIndex]) {
                   let fetchRequest = NSFetchRequest<T>(entityName: T.entity().name!)
                   fetchRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
                   if let existing = try? context.fetch(fetchRequest).first {
                        object = existing // ✅ 기존 객체 재사용
                   } else {
                        object = T(context: context) // ✅ 새로 생성
                        object?.setValue(uuid, forKey: "id")
                   }
                } else {
                    //object = T(context: context) // ❗️id가 아예 없을 때 → 새로 생성
                    // ❌ 유효한 UUID 없으면 import 중단 (덮어쓰기 불가)
                    print("❌ UUID 누락 또는 파싱 실패 → 해당 row 건너뜀")
                    continue
                }

                guard let finalObject = object else { continue }
                                
                // 2. 나머지 필드 매핑
                for (index, key) in keys.enumerated() where index < values.count {
                    
                    // 20250402 csv 로드 중 파싱 에러로 수정
                    let rawValue = values[index]
                    let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
                    let cleanedKey = key.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))

                    guard let attribute = attributes[cleanedKey] else {
                        print("⚠️ 일치하는 속성 없음: \(cleanedKey)")
                        continue
                    }
                    
                    print("🧾 원본 row: \(row)")
                    print("🔑 values: \(values)")
                    print("🧩 매핑 키: \(cleanedKey)")
                    print("🔍 매칭되는 attribute 있음? \(attributes[cleanedKey] != nil)")
                    
                    
                    switch attribute.attributeType {
                    case .UUIDAttributeType:
                        finalObject.setValue(UUID(uuidString: value), forKey: cleanedKey)

                    case .dateAttributeType:
                        // 20250402 파싱 에러로 수정
                        let isoFormatter = ISO8601DateFormatter()
                        let fallbackFormatter = DateFormatter()
                        fallbackFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"

                        if let date = isoFormatter.date(from: value) ?? fallbackFormatter.date(from: value) {
                            finalObject.setValue(date, forKey: cleanedKey)
                        } else if cleanedKey == "createdAt" {
                            print("❌ createdAt 파싱 실패 → 이 객체는 저장 안 됨: \(value)")
                            context.delete(finalObject)
                            continue
                        } else {
                            print("⚠️ 잘못된 날짜: \(value) → \(cleanedKey) 무시됨")
                        }
                    case .integer16AttributeType:
                        finalObject.setValue(Int16(value) ?? 0, forKey: cleanedKey)
                    case .integer32AttributeType:
                        finalObject.setValue(Int32(value) ?? 0, forKey: cleanedKey)
                    case .integer64AttributeType:
                        finalObject.setValue(Int64(value) ?? 0, forKey: cleanedKey)
                    case .booleanAttributeType:
                        finalObject.setValue(value == "1" || value.lowercased() == "true", forKey: cleanedKey)
                    case .stringAttributeType:
                        finalObject.setValue(value, forKey: cleanedKey)
                    default:
                        print("⚠️ 처리되지 않은 타입: \(attribute.attributeType) (\(cleanedKey))")
                    }
                }
            }

            do {
                try context.save()
                print("✅ \(T.self) CSV 복원 완료")
            } catch let error as NSError {
                print("❌ context.save 실패: \(error), \(error.userInfo)")
            }
        } catch {
            print("❌ CSV 파싱 실패: \(error.localizedDescription)")
        }
    }
    
    static func importAllCSVFromDocuments(urls: [URL], context: NSManagedObjectContext) {
        for url in urls {
            let filename = url.lastPathComponent.lowercased()

            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }

                if filename.contains("task") {
                    print("📥 태스크 복원 시작: \(filename)")
                    importCSV(url: url, into: TaskEntity.self, context: context)
                } else if filename.contains("reward") {
                    print("📥 보상 복원 시작: \(filename)")
                    importCSV(url: url, into: RewardEntity.self, context: context)
                } else if filename.contains("user") {
                    print("📥 유저 복원 시작: \(filename)")
                    //importCSV(url: url, into: UserEntity.self, context: context)
                    importUserFromCSV(url: url, context: context)
                } else if filename.contains("challenge") {
                    print("📥 챌린지 복원 시작: \(filename)")
                    importCSV(url: url, into: ChallengeEntity.self, context: context)
                } else if filename.contains("book") {
                    print("📥 독서기록 복원 시작: \(filename)")
                    importCSV(url: url, into: Book.self, context: context)
                } else {
                    print("⚠️ 인식할 수 없는 파일: \(filename) → 스킵됨")
                }
            } else {
                print("❌ 접근 권한 실패: \(url)")
            }
        }
    }
    
    
    /// 지정 디렉토리에 CSV 저장 후 URL 반환 (공유 시트용 임시 폴더 등에 활용)
    static func exportEntityToCSV(entityName: String, filename: String,
                                   to directory: URL, context: NSManagedObjectContext) -> URL? {
        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) else { return nil }
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        do {
            let objects = try context.fetch(fetchRequest)
            let attributeNames = entity.attributesByName.keys.sorted()
            var csvString = attributeNames.joined(separator: ",") + "\n"
            for object in objects {
                let values = attributeNames.map { key -> String in
                    if let value = object.value(forKey: key) { return "\"\(value)\"" }
                    else { return "\"\"" }
                }
                csvString += values.joined(separator: ",") + "\n"
            }
            let fileURL = directory.appendingPathComponent("\(filename).csv")
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Export error: \(error)")
            return nil
        }
    }

    /// 하위 호환용 — Documents 폴더에 저장
    static func exportEntityToCSVToDocuments(entityName: String, filename: String, context: NSManagedObjectContext) -> URL? {
        let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return exportEntityToCSV(entityName: entityName, filename: filename, to: docURL, context: context)
    }

    // MARK: - CSV Parser (Comma-safe)
    static func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var insideQuotes = false

        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current)
        return result
    }

    // MARK: - Multi-file Import
    static func importMultipleCSVFiles(urls: [URL], context: NSManagedObjectContext) {
        for url in urls {
            let filename = url.lastPathComponent
            switch filename {
            case "tasks.csv":
                CSVManager.importCSV(url: url, into: TaskEntity.self, context: context)
            case "rewards.csv":
                CSVManager.importCSV(url: url, into: RewardEntity.self, context: context)
            case "user.csv":
                CSVManager.importUserFromCSV(url: url, context: context)
            case "challenges.csv":
                CSVManager.importCSV(url: url, into: ChallengeEntity.self, context: context)
            case "books.csv":
                CSVManager.importCSV(url: url, into: Book.self, context: context)
            default:
                print("⚠️ 알 수 없는 파일 무시됨: \(filename)")
            }
        }
    }
} 
