//
//  ChallengeViewModel.swift
//  JjingToDo
//
//  Created by Jeongah Seo on 4/29/25.
//

import Foundation
import CoreData

class ChallengeViewModel: ObservableObject {
    @Published var challenges: [ChallengeEntity] = []
    
    private let context = PersistenceController.shared.container.viewContext

    init() {
        fetchChallenges()
    }
    
    func fetchChallenges() {
        let request: NSFetchRequest<ChallengeEntity> = ChallengeEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChallengeEntity.createdAt, ascending: true)]
        
        do {
            challenges = try context.fetch(request)
        } catch {
            print("챌린지 가져오기 실패: \(error.localizedDescription)")
        }
    }
    
    func addChallenge(title: String) {
        let newChallenge = ChallengeEntity(context: context)
        newChallenge.id = UUID()
        newChallenge.title = title.isEmpty ? "Untitled" : title
        newChallenge.challengeType = "routine" // 루틴 타입 고정
        newChallenge.createdAt = Date()
        newChallenge.streakCount = 0
        newChallenge.totalCount = 0
        newChallenge.frequencyCount = 0
        newChallenge.rewardPoint = 0
        newChallenge.lastCompletedAt = nil
        
        saveContext()
        fetchChallenges() // 새로고침
    }
    
    func saveContext() {
        do {
            try context.save()
        } catch {
            print("저장 실패: \(error.localizedDescription)")
        }
    }
}

extension ChallengeViewModel {
    func completeChallenge(_ challenge: ChallengeEntity) {
        //let now = Date()
        let now = Date.adjustedNowBy2AM     // 20250519 챌린지뷰 새벽 2시 기준 제대로 적용 안 되는 것 수정
        
        print("✅ 완료한 챌린지 ID: \(challenge.id?.uuidString ?? "nil")")
        /*print("📋 전체 챌린지 목록:")
        for c in challenges {
            print("- \(c.id?.uuidString ?? "nil"), streak: \(c.streakCount)")
        }
         */
        
        // 기준: 오늘 새벽 2시
        if let last = challenge.lastCompletedAt {
            let gap = now.daysSinceBy2AM(from: last)
            
            if gap == 0 {
                // 오늘 중복 수행 → 변화 없음
            } else if gap == 1 {
                challenge.streakCount += 1  // 어제도 했음 → 연속 성공
            } else {
                challenge.streakCount = 1   // 며칠 안 하다가 오늘 다시 시작 → 연속 실패 후 재시작
            }
        } else {    // 첫 수행 (lastCompletedAt == nil)
            challenge.streakCount = 1
        }
        
        // 수행 기록 업데이트
        challenge.totalCount += 1
        challenge.frequencyCount += 1
        challenge.lastCompletedAt = now

        // 주간 카운트: 이번 주가 바뀌었으면 리셋 후 1, 아니면 +1
        if isNewWeek(since: challenge.weekStartDate) {
            challenge.weeklyCount = 1
            challenge.weekStartDate = currentWeekStart()
        } else {
            challenge.weeklyCount += 1
        }
        
        let safeStreak = max(0, Int(challenge.streakCount))
        let safeFrequency = max(0, Int(challenge.frequencyCount))

        // Morning Challenge를 오전에 수행하면 가산점
        var multiplier = 1
        //let hour = Calendar.current.component(.hour, from: Date())

        if challenge.isMorningChallenge && Date().isMorningBy2AM {
            multiplier = 2
        }
        
        // 포인트 계산 (frequency 기준 + streak 가산)
        let points = calculateRoutinePoint(streak: safeStreak, frequency: safeFrequency) * multiplier
        print("streak: ", safeStreak, ", frequency: ", safeFrequency)
        print("모닝챌린지 가산 배수: ", multiplier, ", 추가될 포인트: ", points)
        
        challenge.rewardPoint = Int32(points)
        
        // UserEntity에도 포인트 합산
        if let user = fetchUser() {
            user.points += Int32(points)
            user.lifetimePoints += Int64(Int32(points))  // 누적 포인트 (lifetimePoints = totalPoints)
        }
        
        // 저장
        saveContext()
        DispatchQueue.main.async {
            self.fetchChallenges()
        }
    }
    
    private func fetchUser() -> UserEntity? {
        let request: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        do {
            let users = try context.fetch(request)
            return users.first
        } catch {
            print("⚠️ 사용자 가져오기 실패: \(error)")
            return nil
        }
    }
}

extension ChallengeViewModel {
    func currentWeekStart() -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2  // 월요일 시작
        return cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
    }

    func isNewWeek(since date: Date?) -> Bool {
        guard let date = date else { return true }
        var cal = Calendar.current
        cal.firstWeekday = 2
        let thisWeek = cal.component(.weekOfYear, from: Date())
        let thisYear = cal.component(.year, from: Date())
        let thatWeek = cal.component(.weekOfYear, from: date)
        let thatYear = cal.component(.year, from: date)
        return thisWeek != thatWeek || thisYear != thatYear
    }
}

extension ChallengeViewModel {
    func calculateRoutinePoint(streak: Int, frequency: Int) -> Int {
        let base = 300
        let frequencyBonus = frequency * 2
        let streakBonus = Int(Double(streak) * 10)
        return base + frequencyBonus + streakBonus
    }
}

