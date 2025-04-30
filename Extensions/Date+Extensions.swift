//
//  Date+Extensions.swift
//  JjingToDo
//
//  Created by Jeongah Seo on 4/30/25.
//

import Foundation

extension Date {
    static var adjustedNowBy2AM: Date {
        let now = Date()
        let calendar = Calendar.current
        let twoAMToday = calendar.date(bySettingHour: 2, minute: 0, second: 0, of: now)!

        return now < twoAMToday
            ? now.addingTimeInterval(-86400) // 하루 전으로 보정
            : now
    }
    
    /// 기준 시간을 새벽 2시로 정한 "오늘" 판별
    func isTodayBy2AM() -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        let baseToday = calendar.date(bySettingHour: 2, minute: 0, second: 0, of: now)!
        let baseSelf = calendar.date(bySettingHour: 2, minute: 0, second: 0, of: self)!

        print("[isTodayBy2AM] baseToday: \(baseToday), baseSelf: \(baseSelf)")
        return calendar.isDate(baseToday, inSameDayAs: baseSelf)
    }

    /// 새벽 2 시 ~ 11:59 사이를 ‘아침’으로 간주
    var isMorningBy2AM: Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: self)
        return hour >= 2 && hour < 12   // 02:00 ≤ time < 12:00
    }
    
    /// 기준 시간을 새벽 2시로 맞춘 후, from → self까지 며칠 차이
    func daysSinceBy2AM(from earlier: Date) -> Int {
        let calendar = Calendar.current
        
        let self2am = calendar.date(bySettingHour: 2, minute: 0, second: 0, of: self)!
        let from2am = calendar.date(bySettingHour: 2, minute: 0, second: 0, of: earlier)!
        
        print("[daysSinceBy2AM] self2am: \(self2am), from2am: \(from2am)")
        return calendar.dateComponents([.day], from: from2am, to: self2am).day ?? 0
    }
    
    func daysSinceOptionalBy2AM(_ date: Date?) -> Int? {
        guard let date else { return nil }
        return Date.adjustedNowBy2AM.daysSinceBy2AM(from: date)
    }
}
