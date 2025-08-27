//
//  BaseNode.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 14.07.2025.
//

import SwiftUI
@preconcurrency import CoreImage

// MARK: - Node Protocol
protocol NodeProtocol: ObservableObject, Identifiable {
    var id: UUID { get }
    var type: NodeType { get }
    var position: CGPoint { get set }
    var title: String { get }
    var inputConnections: [NodeConnection] { get set }
    var outputConnections: [NodeConnection] { get set }
    var inputPorts: [NodePort] { get }
    var outputPorts: [NodePort] { get }
    
    func process(inputs: [CIImage?]) -> CIImage?
    func processAsync(inputs: [CIImage?]) async throws -> CIImage?
    func getParameterKeys() -> [String]
    func setParameter(key: String, value: Any)
    func getParameter(key: String) -> Any?
}

@MainActor
class BaseNode: @preconcurrency NodeProtocol, Equatable {
    let id = UUID()
    let type: NodeType
    @Published var position: CGPoint
    @Published var inputConnections: [NodeConnection] = []
    @Published var outputConnections: [NodeConnection] = []
    
    // Stored ports with consistent IDs
    let inputPorts: [NodePort]
    let outputPorts: [NodePort]
    
    var title: String {
        return type.rawValue
    }
    
    @Published var parameters: [String: Any] = [:]
    
    private var cachedOutput: CIImage?
    private var lastInputHash: Int = 0
    
    init(type: NodeType, position: CGPoint) {
        self.type = type
        self.position = position
        
        // Initialize ports based on metadata - no more switch statements!
        let metadata = type.metadata
        
        self.inputPorts = metadata.inputPorts.map { portDef in
            NodePort(name: portDef.name, type: .input, dataType: portDef.dataType)
        }
        
        self.outputPorts = metadata.outputPorts.map { portDef in
            NodePort(name: portDef.name, type: .output, dataType: portDef.dataType)
        }
    }
    
    // MARK: - Equatable
    
    nonisolated static func == (lhs: BaseNode, rhs: BaseNode) -> Bool {
        return lhs.id == rhs.id
    }
    
    func process(inputs: [CIImage?]) -> CIImage? {
        return inputs.first ?? nil
    }
    
    // MARK: - Async Processing
    
    /// Асинхронная версия обработки - по умолчанию вызывает синхронную версию
    func processAsync(inputs: [CIImage?]) async throws -> CIImage? {
        // По умолчанию выполняем синхронную обработку в фоновом потоке
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.process(inputs: inputs)
                continuation.resume(returning: result)
            }
        }
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
    
    // MARK: - Async Cache Processing
    
    /// Асинхронная версия обработки с кэшированием
    func processWithCacheAsync(inputs: [CIImage?]) async throws -> CIImage? {
        let currentHash = inputs.compactMap { $0?.extent.debugDescription }.joined().hashValue
        
        if currentHash == lastInputHash, let cached = cachedOutput {
            return cached
        }
        
        let result = try await processAsync(inputs: inputs)
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
    
    func invalidateCache() {
        cachedOutput = nil
        lastInputHash = 0
    }
    
    // MARK: - Connection Management
    
    /// Добавляет входящее соединение к ноде
    func addInputConnection(_ connection: NodeConnection) {
        // Prevent duplicate connections
        if !inputConnections.contains(where: { $0.id == connection.id }) {
            inputConnections.append(connection)
        }
    }
        
    /// Удаляет конкретное входящее соединение
    func removeInputConnection(_ connection: NodeConnection) {
        inputConnections.removeAll { $0.id == connection.id }
    }
    
    /// Удаляет все входящие соединения
    func clearInputConnections() {
        inputConnections.removeAll()
    }
        
    /// Добавляет исходящее соединение к ноде
    func addOutputConnection(_ connection: NodeConnection) {
        // Prevent duplicate connections
        if !outputConnections.contains(where: { $0.id == connection.id }) {
            outputConnections.append(connection)
        }
    }
        
    /// Удаляет конкретное исходящее соединение
    func removeOutputConnection(_ connection: NodeConnection) {
        outputConnections.removeAll { $0.id == connection.id }
    }
    
    /// Удаляет все исходящие соединения
    func clearOutputConnections() {
        outputConnections.removeAll()
    }
    
    /// Удаляет конкретное соединение (как входящее, так и исходящее)
    func removeConnection(_ connection: NodeConnection) {
        inputConnections.removeAll { $0.id == connection.id }
        outputConnections.removeAll { $0.id == connection.id }
    }
    
    /// Очищает все соединения ноды
    func clearAllConnections() {
        inputConnections.removeAll()
        outputConnections.removeAll()
    }
}


