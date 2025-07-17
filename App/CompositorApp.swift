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
            
            CommandMenu("View") {
                Button("Viewer") {
                    NotificationCenter.default.post(name: .toggleViewerPanel, object: nil)
                }
                .keyboardShortcut("1", modifiers: [.command])
                
                Button("Node Graph") {
                    NotificationCenter.default.post(name: .toggleNodeGraphPanel, object: nil)
                }
                .keyboardShortcut("2", modifiers: [.command])
                
                Button("Inspector") {
                    NotificationCenter.default.post(name: .toggleInspectorPanel, object: nil)
                }
                .keyboardShortcut("3", modifiers: [.command])
                
                Divider()
                
                Button("Show All") {
                    NotificationCenter.default.post(name: .showAllPanels, object: nil)
                }
                .keyboardShortcut("0", modifiers: [.command, .shift])
            }
        }
    }
}
