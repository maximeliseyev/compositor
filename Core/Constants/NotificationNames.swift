//
//  NotificationNames.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 17.07.2025.
//

import Foundation

extension Notification.Name {
    // Node creation
    static let createNodeFromMenu = Notification.Name("createNodeFromMenu")
    
    // Panel visibility
    static let toggleViewerPanel = Notification.Name("toggleViewerPanel")
    static let toggleNodeGraphPanel = Notification.Name("toggleNodeGraphPanel")
    static let toggleInspectorPanel = Notification.Name("toggleInspectorPanel")
    static let showAllPanels = Notification.Name("showAllPanels")
    
    // Node graph actions
    static let cancelAllConnections = Notification.Name("cancelAllConnections")
} 