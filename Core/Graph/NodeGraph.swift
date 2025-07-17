//
//  NodeGraph.swift
//  Compositor
//

import Foundation
import SwiftUI
import CoreImage

class NodeGraph: ObservableObject {
    @Published var nodes: [BaseNode] = []
    @Published var connections: [NodeConnection] = []
    
    // Быстрый доступ к нодам по id
    private var nodesById: [UUID: BaseNode] = [:]
    
    // MARK: - Node Management
    
    func addNode(_ node: BaseNode) {
        nodes.append(node)
        nodesById[node.id] = node
    }
    
    func removeNode(_ node: BaseNode) {
        // Remove all connections involving this node
        connections.removeAll { connection in
            connection.fromNode == node.id || connection.toNode == node.id
        }
        
        // Remove the node itself
        nodes.removeAll { $0.id == node.id }
        nodesById.removeValue(forKey: node.id)
    }
    
    func moveNode(_ node: BaseNode, to position: CGPoint) {
        if let index = nodes.firstIndex(where: { $0.id == node.id }) {
            nodes[index].position = position
            nodesById[node.id]?.position = position
        }
    }
    
    // MARK: - Port-based Connection Methods
    
    func connectPorts(fromNode: BaseNode, fromPort: NodePort, toNode: BaseNode, toPort: NodePort) -> Bool {
        let validation = validateConnection(fromNode: fromNode, fromPort: fromPort, toNode: toNode, toPort: toPort)
        
        guard validation == .valid else {
            print("Connection validation failed: \(validation.errorMessage)")
            return false
        }
        
        let connection = NodeConnection(
            fromNode: fromNode.id,
            toNode: toNode.id,
            fromPort: fromPort.id,
            toPort: toPort.id
        )
        
        connections.append(connection)
        
        // Update node connections using proper methods
        fromNode.addOutputConnection(connection)
        toNode.addInputConnection(connection)
        
        print("✅ Connection created: \(fromNode.title).\(fromPort.name) -> \(toNode.title).\(toPort.name)")
        return true
    }
    
    func validateConnection(fromNode: BaseNode, fromPort: NodePort, toNode: BaseNode, toPort: NodePort) -> ConnectionValidationResult {
        // Cannot connect to same node
        if fromNode.id == toNode.id {
            return .invalidSameNode
        }
        
        // Port types must be compatible
        if fromPort.type != .output || toPort.type != .input {
            return .invalidPortType
        }
        
        // Data types must match
        if fromPort.dataType != toPort.dataType {
            return .invalidDataType
        }
        
        // Check if input port already has a connection (prevent multiple connections to same input)
        let existingInputConnections = connections.filter { connection in
            connection.toNode == toNode.id && connection.toPort == toPort.id
        }
        
        if !existingInputConnections.isEmpty && !toPort.isMultiInput {
            return .inputAlreadyConnected
        }
        
        // Check for cycle detection
        if wouldCreateCycle(from: fromNode, to: toNode) {
            return .wouldCreateCycle
        }
        
        return .valid
    }
    
    // MARK: - Legacy methods removed - use connectPorts instead for precise control
    
    // MARK: - Connection Management
    
    func addConnection(_ connection: NodeConnection) {
        connections.append(connection)
    }
    
    func removeConnection(_ connection: NodeConnection) {
        connections.removeAll { $0.id == connection.id }
        
        // Update node connections
        if let fromNode = nodes.first(where: { $0.id == connection.fromNode }) {
            fromNode.removeOutputConnection(connection)
        }
        
        if let toNode = nodes.first(where: { $0.id == connection.toNode }) {
            toNode.removeInputConnection(connection)
        }
    }
    
    func removeConnectionsForPort(_ portId: UUID) {
        let connectionsToRemove = connections.filter { connection in
            connection.fromPort == portId || connection.toPort == portId
        }
        
        for connection in connectionsToRemove {
            removeConnection(connection)
        }
    }
    
    // MARK: - Node Parameter Updates
    
    func updateNodeParameter(_ node: BaseNode, key: String, value: Double) {
        if let index = nodes.firstIndex(where: { $0.id == node.id }) {
            nodes[index].parameters[key] = value
        }
    }
    
    // MARK: - Cycle Detection
    
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
    
    // MARK: - Graph Processing
    
    func processGraph() {
        // Implementation for processing the node graph
        // This would typically involve executing nodes in topological order
    }
    
    // MARK: - Helper Methods
    
    func getConnectedPorts(for node: BaseNode) -> (inputs: [NodePort], outputs: [NodePort]) {
        let connectedInputPorts = node.inputPorts.filter { port in
            connections.contains { $0.toNode == node.id && $0.toPort == port.id }
        }
        
        let connectedOutputPorts = node.outputPorts.filter { port in
            connections.contains { $0.fromNode == node.id && $0.fromPort == port.id }
        }
        
        return (connectedInputPorts, connectedOutputPorts)
    }
}
