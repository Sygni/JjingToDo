//
//  AppDelegate.swift
//  JjingToDo
//
//  Created by Jeongah Seo on 4/1/25.
//

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func applicationWillTerminate(_ application: UIApplication) {
        print("🛑 앱 종료됨 - CoreData 저장 시도")

        let context = PersistenceController.shared.container.viewContext
        if context.hasChanges {
            do {
                try context.save()
                print("✅ 앱 종료 시 저장 완료")
            } catch {
                print("❌ 종료 저장 실패: \(error.localizedDescription)")
            }
        }
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        let context = PersistenceController.shared.container.viewContext
        if context.hasChanges {
            do {
                try context.save()
                print("✅ 백그라운드 저장 완료")
            } catch {
                print("❌ 백그라운드 저장 실패: \(error.localizedDescription)")
            }
        }
    }
}
