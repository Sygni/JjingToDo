//
//  HelloSwiftUIApp.swift
//  HelloSwiftUI
//
//  Created by Jeongah Seo on 3/24/25.
//

import SwiftUI

@main
struct JjingToDoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
