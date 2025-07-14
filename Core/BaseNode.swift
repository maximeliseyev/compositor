//
//  BaseNode.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 14.07.2025.
//


import SwiftUI
import CoreImage

protocol NodeProtocol: ObservableObject, Identifiable {
    var id: UUID { get }
    var type: NodeType { get }
    var position: CGPoint { get set }
    var title: String { get }
    var inputConnections: [NodeConnection] { get set }
    var outputConnections: [NodeConnection] { get set }
    
    func process(inputs: [CIImage?]) -> CIImage?
    func getParameterKeys() -> [String]
    func setParameter(key: String, value: Any)
    func getParameter(key: String) -> Any?
}

class BaseNode: NodeProtocol {
    let id = UUID()
    let type: NodeType
    @Published var position: CGPoint
    @Published var inputConnections: [NodeConnection] = []
    @Published var outputConnections: [NodeConnection] = []
    
    var title: String {
        return type.rawValue
    }
    
    @Published var parameters: [String: Any] = [:]
    
    private var cachedOutput: CIImage?
    private var lastInputHash: Int = 0
    
    init(type: NodeType, position: CGPoint) {
        self.type = type
        self.position = position
    }
    
    func process(inputs: [CIImage?]) -> CIImage? {
        return inputs.first ?? nil
    }
    
    func processWithCache(inputs: [CIImage?]) -> CIImage? {
        let currentHash = inputs.compactMap { $0?.extent.debugDescription }.joined().hashValue
        
        if currentHash == lastInputHash, let cached = cachedOutput {
            return cached
        }
        
        let result = process(inputs: inputs)
        cachedOutput = result
        lastInputHash = currentHash
        
        return result
    }
    
    func getParameterKeys() -> [String] {
        return Array(parameters.keys)
    }
    
    func setParameter(key: String, value: Any) {
        parameters[key] = value
        invalidateCache()
    }
    
    func getParameter(key: String) -> Any? {
        return parameters[key]
    }
    
    private func invalidateCache() {
        cachedOutput = nil
        lastInputHash = 0
    }
    
    func addInputConnection(_ connection: NodeConnection) {
            inputConnections.append(connection)
        }
        
    func removeInputConnection(_ connection: NodeConnection) {
        inputConnections.removeAll { $0.id == connection.id }
    }
        
    func addOutputConnection(_ connection: NodeConnection) {
        outputConnections.append(connection)
    }
        
    func removeOutputConnection(_ connection: NodeConnection) {
        outputConnections.removeAll { $0.id == connection.id }
    }
}


