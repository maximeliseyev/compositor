//
//  NodeGraph.swift
//  Compositor
//

import Foundation
import SwiftUI
import CoreImage

/// Граф нод для управления композицией
/// Все операции с графом изолированы на главном акторе для безопасности UI
@MainActor
class NodeGraph: ObservableObject {
    @Published var nodes: [BaseNode] = []
    @Published var connections: [NodeConnection] = []
    
    // Добавляем свойство для отслеживания изменений позиций
    @Published var nodePositionsChanged: Bool = false
    
    // Быстрый доступ к нодам по id
    private var nodesById: [UUID: BaseNode] = [:]
    
    // MARK: - Node Management
    
    func addNode(_ node: BaseNode) {
        nodes.append(node)
        nodesById[node.id] = node
    }
    
    func removeNode(_ node: BaseNode) {
        // Remove all connections involving this node
        removeNodeConnections(node)
        
        // Remove the node itself
        nodes.removeAll { $0.id == node.id }
        nodesById.removeValue(forKey: node.id)
    }
    
    func moveNode(_ node: BaseNode, to position: CGPoint) {
        if let index = nodes.firstIndex(where: { $0.id == node.id }) {
            nodes[index].position = position
            nodesById[node.id]?.position = position
            
            // Уведомляем об изменении позиции для обновления связей
            nodePositionsChanged.toggle()
        }
    }
    
    // Новый метод для обновления позиции в реальном времени
    func updateNodePositionRealtime(_ node: BaseNode, to position: CGPoint) {
        if let index = nodes.firstIndex(where: { $0.id == node.id }) {
            nodes[index].position = position
            nodesById[node.id]?.position = position
            
            // Уведомляем об изменении позиции для обновления связей
            nodePositionsChanged.toggle()
        }
    }
    
    // MARK: - Connection Management
    
    /// Создает соединение между портами двух нод
    func connectPorts(fromNode: BaseNode, fromPort: NodePort, toNode: BaseNode, toPort: NodePort) -> Bool {
        let validation = validateConnection(fromNode: fromNode, fromPort: fromPort, toNode: toNode, toPort: toPort)
        
        guard validation == .valid else {
            return false
        }
        
        // Удаляем все существующие соединения к output порту (одно соединение на порт)
        removeConnectionsToPort(nodeId: fromNode.id, portId: fromPort.id)
        
        // Удаляем все существующие соединения к input порту (одно соединение на порт)
        removeConnectionsToPort(nodeId: toNode.id, portId: toPort.id)
        
        let connection = NodeConnection(
            fromNode: fromNode.id,
            toNode: toNode.id,
            fromPort: fromPort.id,
            toPort: toPort.id
        )
        
        connections.append(connection)
        
        // Обновляем соединения в нодах
        fromNode.addOutputConnection(connection)
        toNode.addInputConnection(connection)
        
        return true
    }
    
    /// Удаляет соединение между нодами
    func disconnectNodes(fromNode: BaseNode, toNode: BaseNode) {
        let connectionsToRemove = connections.filter { connection in
            connection.fromNode == fromNode.id && connection.toNode == toNode.id
        }
        
        for connection in connectionsToRemove {
            removeConnection(connection)
        }
    }
    
    /// Удаляет конкретное соединение
    func removeConnection(_ connection: NodeConnection) {
        // Удаляем соединение из нод
        if let fromNode = nodesById[connection.fromNode] {
            fromNode.removeOutputConnection(connection)
        }
        if let toNode = nodesById[connection.toNode] {
            toNode.removeInputConnection(connection)
        }
        
        // Удаляем соединение из списка
        connections.removeAll { $0.id == connection.id }
    }
    
    /// Удаляет соединения к определенному порту
    func removeConnectionsToPort(nodeId: UUID, portId: UUID) {
        let connectionsToRemove = connections.filter { connection in
            (connection.fromNode == nodeId && connection.fromPort == portId) ||
            (connection.toNode == nodeId && connection.toPort == portId)
        }
        
        for connection in connectionsToRemove {
            removeConnection(connection)
        }
    }
    
    /// Удаляет все соединения ноды
    func removeNodeConnections(_ node: BaseNode) {
        let connectionsToRemove = connections.filter { connection in
            connection.fromNode == node.id || connection.toNode == node.id
        }
        
        for connection in connectionsToRemove {
            removeConnection(connection)
        }
    }
    
    /// Очищает все соединения в графе
    func clearAllConnections() {
        // Очищаем все соединения из нод
        for node in nodes {
            node.clearAllConnections()
        }
        
        // Очищаем список соединений
        connections.removeAll()
    }
    
    // MARK: - Connection Validation
    
    private func validateConnection(fromNode: BaseNode, fromPort: NodePort, toNode: BaseNode, toPort: NodePort) -> ConnectionValidation {
        // Проверяем, что порты существуют
        guard fromNode.outputPorts.contains(where: { $0.id == fromPort.id }) else {
            return .invalidPort
        }
        
        guard toNode.inputPorts.contains(where: { $0.id == toPort.id }) else {
            return .invalidPort
        }
        
        // Проверяем, что не соединяем ноду саму с собой
        guard fromNode.id != toNode.id else {
            return .selfConnection
        }
        
        // Проверяем совместимость типов портов
        guard fromPort.dataType == toPort.dataType else {
            return .typeMismatch
        }
        
        // Проверяем, что output порт не является input портом
        guard fromPort.type == .output else {
            return .invalidPortType
        }
        
        // Проверяем, что to порт является input портом
        guard toPort.type == .input else {
            return .invalidPortType
        }
        
        return .valid
    }
    
    // MARK: - Utility Methods
    
    func getNode(by id: UUID) -> BaseNode? {
        return nodesById[id]
    }
    
    func getConnections(for node: BaseNode) -> [NodeConnection] {
        return connections.filter { connection in
            connection.fromNode == node.id || connection.toNode == node.id
        }
    }
    
    func getInputConnections(for node: BaseNode) -> [NodeConnection] {
        return connections.filter { connection in
            connection.toNode == node.id
        }
    }
    
    func getOutputConnections(for node: BaseNode) -> [NodeConnection] {
        return connections.filter { connection in
            connection.fromNode == node.id
        }
    }
    

    
    func getConnectedNodes(for node: BaseNode) -> [BaseNode] {
        let connectionIds = getConnections(for: node).flatMap { [$0.fromNode, $0.toNode] }
        let uniqueIds = Set(connectionIds).subtracting([node.id])
        return uniqueIds.compactMap { getNode(by: $0) }
    }
    
    func getUpstreamNodes(for node: BaseNode) -> [BaseNode] {
        let inputConnections = getInputConnections(for: node)
        let upstreamIds = inputConnections.map { $0.fromNode }
        return upstreamIds.compactMap { getNode(by: $0) }
    }
    
    func getDownstreamNodes(for node: BaseNode) -> [BaseNode] {
        let outputConnections = getOutputConnections(for: node)
        let downstreamIds = outputConnections.map { $0.toNode }
        return downstreamIds.compactMap { getNode(by: $0) }
    }
    
    func hasCycles() -> Bool {
        var visited = Set<UUID>()
        var recursionStack = Set<UUID>()
        
        func hasCycleDFS(_ nodeId: UUID) -> Bool {
            if recursionStack.contains(nodeId) {
                return true
            }
            
            if visited.contains(nodeId) {
                return false
            }
            
            visited.insert(nodeId)
            recursionStack.insert(nodeId)
            
            guard let node = getNode(by: nodeId) else { return false }
            
            let downstreamNodes = getDownstreamNodes(for: node)
            for downstreamNode in downstreamNodes {
                if hasCycleDFS(downstreamNode.id) {
                    return true
                }
            }
            
            recursionStack.remove(nodeId)
            return false
        }
        
        for node in nodes {
            if !visited.contains(node.id) {
                if hasCycleDFS(node.id) {
                    return true
                }
            }
        }
        
        return false
    }
    
    func getTopologicalSort() -> [BaseNode] {
        var result: [BaseNode] = []
        var visited = Set<UUID>()
        var tempVisited = Set<UUID>()
        
        func topologicalSortDFS(_ node: BaseNode) {
            if tempVisited.contains(node.id) {
                // Цикл обнаружен
                return
            }
            
            if visited.contains(node.id) {
                return
            }
            
            tempVisited.insert(node.id)
            
            let downstreamNodes = getDownstreamNodes(for: node)
            for downstreamNode in downstreamNodes {
                topologicalSortDFS(downstreamNode)
            }
            
            tempVisited.remove(node.id)
            visited.insert(node.id)
            result.append(node)
        }
        
        for node in nodes {
            if !visited.contains(node.id) {
                topologicalSortDFS(node)
            }
        }
        
        return result.reversed()
    }
}

// MARK: - Connection Validation

enum ConnectionValidation {
    case valid
    case invalidPort
    case invalidPortType
    case typeMismatch
    case selfConnection
    case cycleDetected
}

