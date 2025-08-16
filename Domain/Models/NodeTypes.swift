//
//  NodeTypes.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 14.07.2025.
//

import SwiftUI

// MARK: - Node Metadata
struct NodeMetadata {
    let displayName: String
    let description: String
    let iconName: String
    let category: NodeCategory
    let color: String // Цвет как строка для SwiftUI
    let inputPorts: [NodePortDefinition]
    let outputPorts: [NodePortDefinition]
}

struct NodePortDefinition {
    let name: String
    let dataType: NodePortDataType
}

// MARK: - Node Types
enum NodeType: String, CaseIterable {
    case view = "View"
    case input = "Input"
    case corrector = "Corrector"
    case metalCorrector = "MetalCorrector"
    case metalBlur = "MetalBlur"
    case colorWheels = "Color Wheels"
    
    // MARK: - Unified Metadata
    var metadata: NodeMetadata {
        switch self {
        case .view:
            return NodeMetadata(
                displayName: "View Node",
                description: "Display processed image",
                iconName: "eye",
                category: .input_output,
                color: "green",
                inputPorts: [NodePortDefinition(name: "Input", dataType: .image)],
                outputPorts: []
            )
        case .input:
            return NodeMetadata(
                displayName: "Input Node",
                description: "Input source image",
                iconName: "photo",
                category: .input_output,
                color: "blue",
                inputPorts: [],
                outputPorts: [NodePortDefinition(name: "Output", dataType: .image)]
            )
        case .corrector:
            return NodeMetadata(
                displayName: "Corrector Node",
                description: "Apply image corrections",
                iconName: "slider.horizontal.3",
                category: .processing,
                color: "orange",
                inputPorts: [NodePortDefinition(name: "Input", dataType: .image)],
                outputPorts: [NodePortDefinition(name: "Output", dataType: .image)]
            )
        case .metalCorrector:
            return NodeMetadata(
                displayName: "Metal Corrector",
                description: "Apply color corrections using Metal",
                iconName: "paintbrush",
                category: .processing,
                color: "purple",
                inputPorts: [NodePortDefinition(name: "Input", dataType: .image)],
                outputPorts: [NodePortDefinition(name: "Output", dataType: .image)]
            )
        case .metalBlur:
            return NodeMetadata(
                displayName: "Metal Blur",
                description: "Apply blur effects using Metal",
                iconName: "camera.filters",
                category: .processing,
                color: "indigo",
                inputPorts: [NodePortDefinition(name: "Input", dataType: .image)],
                outputPorts: [NodePortDefinition(name: "Output", dataType: .image)]
            )
        case .colorWheels:
            return NodeMetadata(
                displayName: "Color Wheels",
                description: "Professional color correction with lift/gamma/gain controls",
                iconName: "paintpalette",
                category: .processing,
                color: "pink",
                inputPorts: [NodePortDefinition(name: "Input", dataType: .image)],
                outputPorts: [NodePortDefinition(name: "Output", dataType: .image)]
            )
        }
    }
    
    // MARK: - Convenience Properties (делегируют к metadata)
    var displayName: String { metadata.displayName }
    var description: String { metadata.description }
    var iconName: String { metadata.iconName }
    var category: NodeCategory { metadata.category }
    var colorName: String { metadata.color }
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
