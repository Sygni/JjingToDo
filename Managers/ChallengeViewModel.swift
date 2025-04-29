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
        let now = Date()
        let calendar = Calendar.current
        
        // streak 처리
        if let lastCompletedAt = challenge.lastCompletedAt {
            let daysDiff = calendar.dateComponents([.day], from: lastCompletedAt, to: now).day ?? 0
            
            if daysDiff == 1 {
                challenge.streakCount += 1
            } else if daysDiff > 1 {
                challenge.streakCount = 1
            }
        } else {
            // lastCompletedAt이 nil이면 (처음 체크)
            challenge.streakCount = 1
        }
        
        // 수행 기록 업데이트
        // frequency는 무조건 증가 (하루에도 여러 번 누를 수 있음)
        challenge.totalCount += 1
        challenge.frequencyCount += 1
        challenge.lastCompletedAt = now
        
        let safeStreak = max(0, Int(challenge.streakCount))
        let safeFrequency = max(0, Int(challenge.frequencyCount))

        // 포인트 계산 (frequency 기준 + streak 가산)
        let points = calculateRoutinePoint(streak: safeStreak, frequency: safeFrequency)
        print("streak: ", safeStreak, ", frequency: ", safeFrequency, ", 추가될 포인트: ", points)
        challenge.rewardPoint += Int32(points)
        
        // UserEntity에도 포인트 합산
        if let user = fetchUser() {
            user.points += Int32(points)
            user.lifetimePoints += Int64(Int32(points))  // 누적 포인트 (lifetimePoints = totalPoints)
        }
        
        // 저장
        saveContext()
        //fetchChallenges()
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
    func calculateRoutinePoint(streak: Int, frequency: Int) -> Int {
        let base = 100
        let frequencyBonus = frequency * 10
        let streakBonus = Int(Double(streak) * 3)
        return base + frequencyBonus + streakBonus
    }
}

