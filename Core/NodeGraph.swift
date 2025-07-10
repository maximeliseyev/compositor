//
//  NodeGraph.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 10.07.2025.
//


import SwiftUI
import CoreImage

class NodeGraph: ObservableObject {
    @Published var nodes: [CompositorNode] = []
    @Published var connections: [NodeConnection] = []
    
    func addNode(type: NodeType, position: CGPoint) {
        let node = CompositorNode(type: type, position: position)
        nodes.append(node)
    }
    
    func removeNode(_ node: CompositorNode) {
        nodes.removeAll { $0.id == node.id }
        connections.removeAll { $0.fromNode == node.id || $0.toNode == node.id }
    }
    
    func connectNodes(from: CompositorNode, to: CompositorNode) {
        let connection = NodeConnection(fromNode: from.id, toNode: to.id)
        connections.append(connection)
    }
    
    func processGraph() -> CIImage? {
        guard let sourceNode = nodes.first(where: { $0.type == .imageInput }) else { return nil }
        return sourceNode.outputImage
    }
}

struct CompositorNode: Identifiable {
    let id = UUID()
    let type: NodeType
    var position: CGPoint
    var parameters: [String: Double] = [:]
    var inputImage: CIImage?
    var outputImage: CIImage?
    
    init(type: NodeType, position: CGPoint) {
        self.type = type
        self.position = position
        
        switch type {
        case .imageInput:
            break
        case .colorCorrection:
            parameters = ["brightness": 0.0, "contrast": 1.0, "saturation": 1.0]
        case .blur:
            parameters = ["radius": 5.0]
        case .sharpen:
            parameters = ["radius": 2.5, "intensity": 0.5]
        case .output:
            break
        }
    }
}

struct NodeConnection: Identifiable {
    let id = UUID()
    let fromNode: UUID
    let toNode: UUID
}

enum NodeType: String, CaseIterable {
    case imageInput = "Image Input"
    case colorCorrection = "Color Correction"
    case blur = "Blur"
    case sharpen = "Sharpen"
    case output = "Output"
}
