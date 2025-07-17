//
//  NodeGraphConnectionManager.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 17.07.2025.
//

import SwiftUI
import Foundation

/// Управляет соединениями между нодами, включая drag & drop операции
@MainActor
class NodeGraphConnectionManager: ObservableObject {
    // MARK: - Properties
    
    @Published var connectionDragFromNodeID: UUID? = nil
    @Published var connectionDragFromPortID: UUID? = nil
    @Published var connectionDragFromPosition: CGPoint? = nil
    @Published var connectionDragCurrentPosition: CGPoint? = nil
    @Published var connectionDragToNodeID: UUID? = nil
    @Published var connectionDragToPortID: UUID? = nil
    
    private var lastPreviewUpdateTime: TimeInterval = 0
    private let maxUpdateFrequency: TimeInterval = 1.0 / 60.0 // 60 FPS
    
    // MARK: - Connection Drag Management
    
    func startPortConnection(fromNodeID: UUID, fromPortID: UUID, portPosition: CGPoint, cache: NodeGraphCache) {
        guard let fromNode = cache.getCachedNode(id: fromNodeID),
              let _ = (fromNode.inputPorts + fromNode.outputPorts).first(where: { $0.id == fromPortID }) else {
            return
        }
        
        connectionDragFromNodeID = fromNodeID
        connectionDragFromPortID = fromPortID
        connectionDragFromPosition = portPosition
        connectionDragCurrentPosition = portPosition
        connectionDragToNodeID = nil
        connectionDragToPortID = nil
    }
    
    func updateConnectionDrag(to position: CGPoint, cache: NodeGraphCache) {
        let now = CACurrentMediaTime()
        if now - lastPreviewUpdateTime < maxUpdateFrequency { return }
        lastPreviewUpdateTime = now
        
        connectionDragCurrentPosition = position
        
        let (targetNode, targetPort) = findTargetAtPosition(position, cache: cache)
        connectionDragToNodeID = targetNode?.id
        connectionDragToPortID = targetPort?.id
    }
    
    func endPortConnection(toNodeID: UUID, toPortID: UUID, cache: NodeGraphCache, nodeGraph: NodeGraph) {
        guard let toNode = cache.getCachedNode(id: toNodeID),
              let _ = (toNode.inputPorts + toNode.outputPorts).first(where: { $0.id == toPortID }) else {
            resetConnectionDrag()
            return
        }
                
        if let targetNodeID = connectionDragToNodeID,
           let targetPortID = connectionDragToPortID,
           let fromNodeID = connectionDragFromNodeID,
           let fromPortID = connectionDragFromPortID,
           let fromNode = cache.getCachedNode(id: fromNodeID),
           let toNode = cache.getCachedNode(id: targetNodeID),
           let fromPort = (fromNode.inputPorts + fromNode.outputPorts).first(where: { $0.id == fromPortID }),
           let toPort = (toNode.inputPorts + toNode.outputPorts).first(where: { $0.id == targetPortID }) {
            
            if fromPort.type == NodePortType.output && toPort.type == NodePortType.input {
                let _ = nodeGraph.connectPorts(fromNode: fromNode, fromPort: fromPort, toNode: toNode, toPort: toPort)
            } else if fromPort.type == NodePortType.input && toPort.type == NodePortType.output {
                let _ = nodeGraph.connectPorts(fromNode: toNode, fromPort: toPort, toNode: fromNode, toPort: fromPort)
            }
        }
        
        resetConnectionDrag()
    }
    
    func resetConnectionDrag() {
        connectionDragFromNodeID = nil
        connectionDragFromPortID = nil
        connectionDragFromPosition = nil
        connectionDragCurrentPosition = nil
        connectionDragToNodeID = nil
        connectionDragToPortID = nil
    }
    
    // MARK: - Port Finding
    
    private func findTargetAtPosition(_ position: CGPoint, cache: NodeGraphCache) -> (BaseNode?, NodePort?) {
        let snapDistance: CGFloat = 20
        var closestNode: BaseNode? = nil
        var closestPort: NodePort? = nil
        var closestDistance: CGFloat = snapDistance
        
        // Используем кэшированные ноды для быстрого поиска
        for node in cache.getAllCachedNodes() {
            // Сначала проверяем, находится ли точка рядом с нодой
            let nodeDistance = cache.distance(from: position, to: node.position)
            if nodeDistance > snapDistance * 3 { continue } // Быстрая отсечка
            
            // Проверяем input порты
            for port in node.inputPorts {
                let portPosition = cache.getCachedPortPosition(node: node, port: port)
                let dist = cache.distance(from: position, to: portPosition)
                
                if dist < closestDistance {
                    closestDistance = dist
                    closestNode = node
                    closestPort = port
                }
            }
            
            // Проверяем output порты
            for port in node.outputPorts {
                let portPosition = cache.getCachedPortPosition(node: node, port: port)
                let dist = cache.distance(from: position, to: portPosition)
                
                if dist < closestDistance {
                    closestDistance = dist
                    closestNode = node
                    closestPort = port
                }
            }
        }
        
        return (closestNode, closestPort)
    }
    
    // MARK: - Connection Rendering Helpers
    
    func hasActiveConnection() -> Bool {
        return connectionDragFromPosition != nil && connectionDragCurrentPosition != nil
    }
    
    func getPreviewConnectionPoints() -> (CGPoint, CGPoint)? {
        guard let from = connectionDragFromPosition,
              let to = connectionDragCurrentPosition else {
            return nil
        }
        return (from, to)
    }
} 