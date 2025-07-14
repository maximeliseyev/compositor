//
//  CompositorApp.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 10.07.2025.
//

import SwiftUI
import AppKit

@main
struct SwiftCompositorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandMenu("Node") {
                ForEach(NodeType.allCases, id: \.self) { type in
                    Button("Create \(type.rawValue) Node") {
                        NotificationCenter.default.post(name: .createNodeFromMenu, object: type)
                    }
                }
            }
        }
    }
}

extension Notification.Name {
    static let createNodeFromMenu = Notification.Name("createNodeFromMenu")
}
