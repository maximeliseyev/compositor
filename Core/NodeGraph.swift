//
//  NodeGraph.swift
//  Compositor
//
//

import SwiftUI
import CoreImage

class NodeGraph: ObservableObject {
    @Published var nodes: [BaseNode] = []
    @Published var connections: [NodeConnection] = []
    
    func addNode(_ node: BaseNode) {
        nodes.append(node)
    }
    
    func removeNode(_ node: BaseNode) {
        nodes.removeAll { $0.id == node.id }
        connections.removeAll { $0.fromNode == node.id || $0.toNode == node.id }
    }
    
    func moveNode(_ node: BaseNode, to position: CGPoint) {
        if let index = nodes.firstIndex(where: { $0.id == node.id }) {
            nodes[index].position = position
        }
    }
    
    func connectNodes(from: BaseNode, to: BaseNode) {
        // Проверяем, что соединение не создаст цикл
        if !wouldCreateCycle(from: from, to: to) {
            let connection = NodeConnection(fromNode: from.id, toNode: to.id)
            connections.append(connection)
        }
    }
    
    func addConnection(_ connection: NodeConnection) {
        connections.append(connection)
    }
    
    func removeConnection(_ connection: NodeConnection) {
        connections.removeAll { $0.id == connection.id }
    }
    
    func updateNodeParameter(_ node: BaseNode, key: String, value: Double) {
        if let index = nodes.firstIndex(where: { $0.id == node.id }) {
            nodes[index].parameters[key] = value
        }
    }
    
    
    private func wouldCreateCycle(from: BaseNode, to: BaseNode) -> Bool {
        var visited = Set<UUID>()
        
        func canReach(_ nodeId: UUID, target: UUID) -> Bool {
            if visited.contains(nodeId) {
                return false
            }
            
            if nodeId == target {
                return true
            }
            
            visited.insert(nodeId)
            
            let outgoingConnections = connections.filter { $0.fromNode == nodeId }
            for connection in outgoingConnections {
                if canReach(connection.toNode, target: target) {
                    return true
                }
            }
            
            return false
        }
        
        return canReach(to.id, target: from.id)
    }
}

struct NodeConnection: Identifiable {
    let id = UUID()
    let fromNode: UUID
    let toNode: UUID
}
