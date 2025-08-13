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
    case metalCorrector = "MetalCorrector"
    case metalBlur = "MetalBlur"
    
    // MARK: - UI Properties
    var displayName: String {
        switch self {
        case .view:
            return "View Node"
        case .input:
            return "Input Node"
        case .corrector:
            return "Corrector Node"
        case .metalCorrector:
            return "Metal Corrector"
        case .metalBlur:
            return "Metal Blur"
        }
    }
    
    var description: String {
        switch self {
        case .view:
            return "Display processed image"
        case .input:
            return "Input source image"
        case .corrector:
            return "Apply image corrections"
        case .metalCorrector:
            return "Apply color corrections using Metal"
        case .metalBlur:
            return "Apply blur effects using Metal"
        }
    }
    
    var iconName: String {
        switch self {
        case .view:
            return "eye"
        case .input:
            return "photo"
        case .corrector:
            return "slider.horizontal.3"
        case .metalCorrector:
            return "paintbrush"
        case .metalBlur:
            return "camera.filters"
        }
    }
    
    var category: NodeCategory {
        switch self {
        case .input:
            return .input_output
        case .corrector:
            return .processing
        case .metalCorrector:
            return .processing
        case .metalBlur:
            return .processing
        case .view:
            return .input_output
        }
    }
}

// MARK: - Node Categories
enum NodeCategory: String, CaseIterable {
    case input_output = "Input/Output"
    case processing = "Processing"
    
    var displayName: String {
        return rawValue
    }
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
