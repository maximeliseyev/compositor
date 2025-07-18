//
//  NodeGraphCache.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 17.07.2025.
//

import SwiftUI
import Foundation

/// Управляет кэшированием нод, позиций портов и соединений для оптимизации производительности
@MainActor
class NodeGraphCache: ObservableObject {
    // MARK: - Properties
    
    private var nodeCache: [UUID: BaseNode] = [:]
    private var portPositionCache: [String: CGPoint] = [:]
    private var connectionCache: [UUID: (CGPoint, CGPoint)] = [:]
    
    // Throttling для обновлений
    private let maxUpdateFrequency: TimeInterval = 1.0 / 60.0 // 60 FPS
    private var lastCacheUpdateTime: TimeInterval = 0
    private var lastConnectionClearTime: TimeInterval = 0
    private var lastPositionClearTime: TimeInterval = 0
    
    // MARK: - Node Cache Management
    
    func updateNodeCache(nodes: [BaseNode]) {
        let now = CACurrentMediaTime()
        if now - lastCacheUpdateTime < maxUpdateFrequency { return }
        lastCacheUpdateTime = now
        
        // Обновляем кэш нод
        var newCache: [UUID: BaseNode] = [:]
        for node in nodes {
            newCache[node.id] = node
        }
        nodeCache = newCache
        
        // Очищаем кэш позиций портов для пересчета
        portPositionCache.removeAll()
        connectionCache.removeAll()
    }
    
    func getCachedNode(id: UUID) -> BaseNode? {
        return nodeCache[id]
    }
    
    func getAllCachedNodes() -> [BaseNode] {
        return Array(nodeCache.values)
    }
    
    func removeNodeFromCache(_ nodeId: UUID) {
        nodeCache.removeValue(forKey: nodeId)
        clearPositionCacheForNode(nodeId)
    }
    
    // MARK: - Port Position Cache Management
    
    func getCachedPortPosition(node: BaseNode, port: NodePort) -> CGPoint {
        let cacheKey = "\(node.id)_\(port.id)"
        
        if let cachedPosition = portPositionCache[cacheKey] {
            return cachedPosition
        }
        
        let position = calculatePortPosition(node: node, port: port)
        portPositionCache[cacheKey] = position
        return position
    }
    
    private func calculatePortPosition(node: BaseNode, port: NodePort) -> CGPoint {
        if port.type == NodePortType.input {
            guard let portIndex = node.inputPorts.firstIndex(where: { $0.id == port.id }) else {
                return NodeViewConstants.inputPortPosition(at: node.position)
            }
            return NodeViewConstants.inputPortPosition(
                at: node.position,
                portIndex: portIndex,
                totalPorts: node.inputPorts.count
            )
        } else {
            guard let portIndex = node.outputPorts.firstIndex(where: { $0.id == port.id }) else {
                return NodeViewConstants.outputPortPosition(at: node.position)
            }
            return NodeViewConstants.outputPortPosition(
                at: node.position,
                portIndex: portIndex,
                totalPorts: node.outputPorts.count
            )
        }
    }
    
    func clearPositionCacheForNode(_ nodeId: UUID) {
        // Throttling для предотвращения слишком частых обновлений при перетаскивании
        let now = CACurrentMediaTime()
        if now - lastPositionClearTime < maxUpdateFrequency / 2 { return } // Позволяем обновления в 2 раза чаще
        lastPositionClearTime = now
        
        let nodePortKeys = portPositionCache.keys.filter { $0.hasPrefix("\(nodeId)_") }
        for key in nodePortKeys {
            portPositionCache.removeValue(forKey: key)
        }
    }
    
    // Немедленная очистка кэша позиций без throttling (для финальных обновлений)
    func clearPositionCacheForNodeImmediate(_ nodeId: UUID) {
        let nodePortKeys = portPositionCache.keys.filter { $0.hasPrefix("\(nodeId)_") }
        for key in nodePortKeys {
            portPositionCache.removeValue(forKey: key)
        }
    }
    
    // MARK: - Connection Cache Management
    
    func getCachedConnectionPoints(for connection: NodeConnection, fromNode: BaseNode, toNode: BaseNode) -> (CGPoint, CGPoint) {
        if let cached = connectionCache[connection.id] {
            return cached
        }
        
        let points = calculateConnectionPoints(for: connection, fromNode: fromNode, toNode: toNode)
        connectionCache[connection.id] = points
        return points
    }
    
    private func calculateConnectionPoints(for connection: NodeConnection, fromNode: BaseNode, toNode: BaseNode) -> (CGPoint, CGPoint) {
        let fromPoint: CGPoint
        let toPoint: CGPoint
        
        if let fromPort = fromNode.outputPorts.first(where: { $0.id == connection.fromPort }) {
            fromPoint = getCachedPortPosition(node: fromNode, port: fromPort)
        } else {
            fromPoint = CGPoint(x: fromNode.position.x, y: fromNode.position.y + 30)
        }
        
        if let toPort = toNode.inputPorts.first(where: { $0.id == connection.toPort }) {
            toPoint = getCachedPortPosition(node: toNode, port: toPort)
        } else {
            toPoint = CGPoint(x: toNode.position.x, y: toNode.position.y - 30)
        }
        
        return (fromPoint, toPoint)
    }
    
    func clearConnectionCacheForNode(_ nodeId: UUID, connections: [NodeConnection]) {
        // Throttling для предотвращения слишком частых обновлений при перетаскивании
        let now = CACurrentMediaTime()
        if now - lastConnectionClearTime < maxUpdateFrequency / 2 { return } // Позволяем обновления в 2 раза чаще
        lastConnectionClearTime = now
        
        let connectionsToUpdate = connections.filter { 
            $0.fromNode == nodeId || $0.toNode == nodeId 
        }
        for connection in connectionsToUpdate {
            connectionCache.removeValue(forKey: connection.id)
        }
    }
    
    // Немедленная очистка кэша связей без throttling (для финальных обновлений)
    func clearConnectionCacheForNodeImmediate(_ nodeId: UUID, connections: [NodeConnection]) {
        let connectionsToUpdate = connections.filter { 
            $0.fromNode == nodeId || $0.toNode == nodeId 
        }
        for connection in connectionsToUpdate {
            connectionCache.removeValue(forKey: connection.id)
        }
    }
    
    // MARK: - Cache Cleanup
    
    func clearAllCaches() {
        nodeCache.removeAll()
        portPositionCache.removeAll()
        connectionCache.removeAll()
    }
    
    // MARK: - Utility Methods
    
    func distance(from point1: CGPoint, to point2: CGPoint) -> CGFloat {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        return sqrt(dx * dx + dy * dy)
    }
} 