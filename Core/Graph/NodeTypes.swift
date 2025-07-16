//
//  NodeTypes.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 14.07.2025.
//

import SwiftUI

// MARK: - Node Types
enum NodeType: String, CaseIterable {
    case view = "View"
    case input = "Input"
    case corrector = "Corrector"
}

// MARK: - NodePort Structure
struct NodePort: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let type: NodePortType
    let dataType: NodePortDataType
    let isMultiInput: Bool // Allows multiple connections to input port
    
    init(name: String, type: NodePortType, dataType: NodePortDataType = .image, isMultiInput: Bool = false) {
        self.name = name
        self.type = type
        self.dataType = dataType
        self.isMultiInput = isMultiInput
    }
}

enum NodePortType {
    case input
    case output
}

enum NodePortDataType {
    case image
    case mask
    case value
}

// MARK: - Node Connection Structure
struct NodeConnection: Identifiable, Equatable {
    let id = UUID()
    let fromNode: UUID
    let toNode: UUID
    let fromPort: UUID? // Port ID for more precise connections
    let toPort: UUID? // Port ID for more precise connections
    
    init(fromNode: UUID, toNode: UUID, fromPort: UUID? = nil, toPort: UUID? = nil) {
        self.fromNode = fromNode
        self.toNode = toNode
        self.fromPort = fromPort
        self.toPort = toPort
    }
    
    // Helper methods for port-based connections
    func hasPortInfo() -> Bool {
        return fromPort != nil && toPort != nil
    }
    
    func isCompatible(with outputPort: NodePort, inputPort: NodePort) -> Bool {
        // Check if data types are compatible
        return outputPort.dataType == inputPort.dataType
    }
    
    // Static methods for creating connections
    static func createPortConnection(from fromNode: UUID, fromPort: UUID, to toNode: UUID, toPort: UUID) -> NodeConnection {
        return NodeConnection(fromNode: fromNode, toNode: toNode, fromPort: fromPort, toPort: toPort)
    }
    
    static func createNodeConnection(from fromNode: UUID, to toNode: UUID) -> NodeConnection {
        return NodeConnection(fromNode: fromNode, toNode: toNode)
    }
} 