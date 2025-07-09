//
//  CompositorApp.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 10.07.2025.
//

import SwiftUI

@main
struct CompositorApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
