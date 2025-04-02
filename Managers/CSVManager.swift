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

            let keys = rows[0].components(separatedBy: ",").map { $0.replacingOccurrences(of: "\"", with: "") }
            let values = rows[1].components(separatedBy: ",")
            //let values = parseCSVLine(rows[1])

            // ✅ 기존 유저 전부 삭제
            let fetchRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
            let existingUsers = try context.fetch(fetchRequest)
            for user in existingUsers {
                context.delete(user)
            }
            
            //let request: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
            //let users = try context.fetch(request)
            //let user = users.first ?? UserEntity(context: context)
            
            // ✅ 새 유저 생성
            let user = UserEntity(context: context)
            
            /*
            for (index, key) in keys.enumerated() where index < values.count {
                let value = values[index]
                switch key.trimmingCharacters(in: .whitespacesAndNewlines) {
                case "points": user.points = Int32(value) ?? 0
                case "lifetimePoints": user.lifetimePoints = Int64(value) ?? 0
                default: break
                }
            }
            */
            for (index, key) in keys.enumerated() where index < values.count {
                let cleanedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
                let value = values[index].trimmingCharacters(in: .whitespacesAndNewlines)

                switch cleanedKey {
                case "id":
                    if let uuid = UUID(uuidString: value) {
                        user.id = uuid
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
                    print("⚠️ 매핑되지 않은 키: \(cleanedKey)")
                    break
                }
            }

            try context.save()
            print("✅ UserEntity 복원 완료")
            
            // 20250402 디버그용 로그
            //let debug_request: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
            //let debug_users = try context.fetch(debug_request)
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
                let object = T(context: context)
                let attributes = T.entity().attributesByName
     
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
                        object.setValue(UUID(uuidString: value), forKey: cleanedKey)

                    case .dateAttributeType:
                        // 20250402 파싱 에러로 수정
                        let isoFormatter = ISO8601DateFormatter()
                        let fallbackFormatter = DateFormatter()
                        fallbackFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"

                        if let date = isoFormatter.date(from: value) ?? fallbackFormatter.date(from: value) {
                            object.setValue(date, forKey: cleanedKey)
                        } else if cleanedKey == "createdAt" {
                            print("❌ createdAt 파싱 실패 → 이 객체는 저장 안 됨: \(value)")
                            context.delete(object)
                            continue
                        } else {
                            print("⚠️ 잘못된 날짜: \(value) → \(cleanedKey) 무시됨")
                        }
                    case .integer16AttributeType:
                        object.setValue(Int16(value) ?? 0, forKey: cleanedKey)
                    case .integer32AttributeType:
                        object.setValue(Int32(value) ?? 0, forKey: cleanedKey)
                    case .integer64AttributeType:
                        object.setValue(Int64(value) ?? 0, forKey: cleanedKey)
                    case .booleanAttributeType:
                        object.setValue(value == "1" || value.lowercased() == "true", forKey: cleanedKey)
                    case .stringAttributeType:
                        object.setValue(value, forKey: cleanedKey)
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
                    importCSV(url: url, into: UserEntity.self, context: context)
                } else {
                    print("⚠️ 인식할 수 없는 파일: \(filename) → 스킵됨")
                }
            } else {
                print("❌ 접근 권한 실패: \(url)")
            }
        }
    }
    
    
    static func exportEntityToCSVToDocuments(entityName: String, filename: String, context: NSManagedObjectContext) -> URL? {
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
            default:
                print("⚠️ 알 수 없는 파일 무시됨: \(filename)")
            }
        }
    }
} 
