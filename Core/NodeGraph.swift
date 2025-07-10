//
//  NodeGraph.swift
//  Compositor
//
//  Enhanced with proper graph processing
//

import SwiftUI
import CoreImage

class NodeGraph: ObservableObject {
    @Published var nodes: [CompositorNode] = []
    @Published var connections: [NodeConnection] = []
    private let imageProcessor = ImageProcessor()
    
    func addNode(type: NodeType, position: CGPoint) {
        let node = CompositorNode(type: type, position: position)
        nodes.append(node)
    }
    
    func addInputNode(image: NSImage, position: CGPoint) -> CompositorNode {
        let node = CompositorNode(type: .imageInput, position: position)
        setInputImage(for: node, image: image)
        nodes.append(node)
        return node
    }
    
    func removeNode(_ node: CompositorNode) {
        nodes.removeAll { $0.id == node.id }
        connections.removeAll { $0.fromNode == node.id || $0.toNode == node.id }
    }
    
    func moveNode(_ node: CompositorNode, to position: CGPoint) {
        if let index = nodes.firstIndex(where: { $0.id == node.id }) {
            nodes[index].position = position
        }
    }
    
    func connectNodes(from: CompositorNode, to: CompositorNode) {
        // Проверяем, что соединение не создаст цикл
        if !wouldCreateCycle(from: from, to: to) {
            let connection = NodeConnection(fromNode: from.id, toNode: to.id)
            connections.append(connection)
        }
    }
    
    func setInputImage(for node: CompositorNode, image: NSImage) {
        if let index = nodes.firstIndex(where: { $0.id == node.id }) {
            guard let ciImage = CIImage(data: image.tiffRepresentation!) else { return }
            nodes[index].inputImage = ciImage
            nodes[index].outputImage = ciImage
        }
    }
    
    func updateNodeParameter(_ node: CompositorNode, key: String, value: Double) {
        if let index = nodes.firstIndex(where: { $0.id == node.id }) {
            nodes[index].parameters[key] = value
        }
    }
    
    func processGraph() -> CIImage? {
        // Находим все входные ноды
        let inputNodes = nodes.filter { $0.type == .imageInput }
        guard !inputNodes.isEmpty else { return nil }
        
        // Сбрасываем все выходные изображения кроме входных
        for i in 0..<nodes.count {
            if nodes[i].type != .imageInput {
                nodes[i].outputImage = nil
            }
        }
        
        // Обрабатываем граф в топологическом порядке
        let sortedNodes = topologicalSort()
        
        for node in sortedNodes {
            processNode(node)
        }
        
        // Возвращаем результат из выходного нода или последнего обработанного
        if let outputNode = nodes.first(where: { $0.type == .output }) {
            return outputNode.outputImage
        } else {
            return sortedNodes.last?.outputImage
        }
    }
    
    private func processNode(_ node: CompositorNode) {
        guard let nodeIndex = nodes.firstIndex(where: { $0.id == node.id }) else { return }
        
        switch node.type {
        case .imageInput:
            // Входной нод уже имеет изображение
            return
            
        case .colorCorrection:
            guard let inputImage = getInputImage(for: node) else { return }
            let filter = ImageFilter(
                name: "Color Correction",
                type: .colorControls,
                parameters: node.parameters
            )
            nodes[nodeIndex].outputImage = imageProcessor.applyFilter(filter, to: inputImage)
            
        case .blur:
            guard let inputImage = getInputImage(for: node) else { return }
            let filter = ImageFilter(
                name: "Blur",
                type: .blur,
                parameters: node.parameters
            )
            nodes[nodeIndex].outputImage = imageProcessor.applyFilter(filter, to: inputImage)
            
        case .sharpen:
            guard let inputImage = getInputImage(for: node) else { return }
            let filter = ImageFilter(
                name: "Sharpen",
                type: .sharpen,
                parameters: node.parameters
            )
            nodes[nodeIndex].outputImage = imageProcessor.applyFilter(filter, to: inputImage)
            
        case .output:
            guard let inputImage = getInputImage(for: node) else { return }
            nodes[nodeIndex].outputImage = inputImage
        }
    }
    
    private func getInputImage(for node: CompositorNode) -> CIImage? {
        // Находим входящее соединение
        guard let connection = connections.first(where: { $0.toNode == node.id }) else {
            return nil
        }
        
        // Находим исходный нод
        guard let sourceNode = nodes.first(where: { $0.id == connection.fromNode }) else {
            return nil
        }
        
        return sourceNode.outputImage
    }
    
    private func topologicalSort() -> [CompositorNode] {
        var visited = Set<UUID>()
        var result: [CompositorNode] = []
        
        func visit(_ node: CompositorNode) {
            if visited.contains(node.id) {
                return
            }
            
            visited.insert(node.id)
            
            // Сначала посещаем все зависимости
            let dependencies = connections
                .filter { $0.toNode == node.id }
                .compactMap { connection in
                    nodes.first { $0.id == connection.fromNode }
                }
            
            for dependency in dependencies {
                visit(dependency)
            }
            
            result.append(node)
        }
        
        for node in nodes {
            visit(node)
        }
        
        return result
    }
    
    private func wouldCreateCycle(from: CompositorNode, to: CompositorNode) -> Bool {
        // Простая проверка циклов - проверяем, может ли to достигнуть from
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
