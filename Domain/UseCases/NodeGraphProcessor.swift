//
//  NodeGraphProcessor.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 19.07.2025.
//

import Foundation
import CoreImage
import Combine

/// Класс для обработки графа нод и автоматической передачи данных
class NodeGraphProcessor: ObservableObject {
    private weak var nodeGraph: NodeGraph? // Weak reference to prevent retain cycles
    private var cancellables = Set<AnyCancellable>()
    
    // Кэш обработанных данных для избежания повторных вычислений
    private var processCache: [UUID: CIImage?] = [:]
    private var lastProcessTime: [UUID: Date] = [:]
    
    // Memory management constants
    private let maxCacheSize = 50
    private let cacheExpirationTime: TimeInterval = 30.0
    
    init(nodeGraph: NodeGraph) {
        self.nodeGraph = nodeGraph
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        guard let nodeGraph = nodeGraph else { return }
        
        // Подписка на изменения в графе
        nodeGraph.$connections
            .sink { [weak self] _ in
                self?.invalidateCache()
                self?.processGraph()
            }
            .store(in: &cancellables)
        
        // Подписка на изменения нод
        nodeGraph.$nodes
            .sink { [weak self] _ in
                self?.invalidateCache()
                self?.processGraph()
            }
            .store(in: &cancellables)
    }
    
    /// Обрабатывает весь граф нод
    func processGraph() {
        guard nodeGraph != nil else { return }
        
        cleanupExpiredCache()
        let sortedNodes = topologicalSort()
        
        #if DEBUG
        print("🧮 Processing graph, nodes order: \(sortedNodes.map{ $0.type.rawValue })")
        #endif
        
        for node in sortedNodes {
            processNode(node)
        }
    }
    
    /// Обрабатывает конкретную ноду
    func processNode(_ node: BaseNode) {
        // Получаем входные данные из соединенных нод
        let inputs = getInputsForNode(node)
        
        // Обрабатываем ноду
        let output = node.processWithCache(inputs: inputs)
        #if DEBUG
        if let out = output {
            print("✅ Node \(node.type.rawValue) produced: extent=\(out.extent)")
        } else {
            print("⚠️ Node \(node.type.rawValue) produced nil")
        }
        #endif
        
        // Кэшируем результат
        processCache[node.id] = output
        lastProcessTime[node.id] = Date()
        
        // Особая обработка для InputNode - запускаем обработку при изменении медиа
        if let inputNode = node as? InputNode {
            setupInputNodeObservation(inputNode)
        }
    }
    
    /// Получает входные данные для ноды из соединенных output-нод
    private func getInputsForNode(_ node: BaseNode) -> [CIImage?] {
        guard let nodeGraph = nodeGraph else { return [] }
        
        // Сортируем input connections по порядку портов
        let sortedInputs = node.inputPorts.map { inputPort in
            // Находим соединение к этому input порту
            let connection = nodeGraph.connections.first { conn in
                conn.toNode == node.id && conn.toPort == inputPort.id
            }
            
            guard let connection = connection else {
                return nil as CIImage?
            }
            
            // Находим source ноду
            guard let sourceNode = nodeGraph.nodes.first(where: { $0.id == connection.fromNode }) else {
                return nil
            }
            
            // Возвращаем кэшированный результат или обрабатываем source ноду
            if let cachedResult = processCache[sourceNode.id],
               let lastTime = lastProcessTime[sourceNode.id],
               Date().timeIntervalSince(lastTime) < 0.1 {
                return cachedResult
            } else {
                let sourceOut = sourceNode.processWithCache(inputs: getInputsForNode(sourceNode))
                #if DEBUG
                if let so = sourceOut {
                    print("↪️  input for \(node.type.rawValue) from \(sourceNode.type.rawValue): extent=\(so.extent)")
                } else {
                    print("↪️  input for \(node.type.rawValue) from \(sourceNode.type.rawValue): nil")
                }
                #endif
                return sourceOut
            }
        }
        
        return sortedInputs
    }
    
    /// Настройка наблюдения за изменениями в InputNode
    private func setupInputNodeObservation(_ inputNode: InputNode) {
        // Отслеживаем изменения в изображении
        inputNode.$ciImage
            .dropFirst()
            .sink { [weak self] _ in
                self?.onInputNodeChanged(inputNode)
            }
            .store(in: &cancellables)
        
        // Отслеживаем изменения в видео
        inputNode.$videoProcessor
            .dropFirst()
            .sink { [weak self] _ in
                self?.onInputNodeChanged(inputNode)
            }
            .store(in: &cancellables)
        
        // Отслеживаем изменения текущего времени видео
        if let videoProcessor = inputNode.videoProcessor {
            videoProcessor.$currentTime
                .dropFirst()
                .sink { [weak self] _ in
                    self?.onInputNodeChanged(inputNode)
                }
                .store(in: &cancellables)
        }
    }
    
    /// Вызывается при изменении InputNode
    private func onInputNodeChanged(_ inputNode: InputNode) {
        // Инвалидируем кэш для этой ноды
        processCache.removeValue(forKey: inputNode.id)
        
        // Находим все ноды, которые зависят от этой input ноды
        let dependentNodes = findDependentNodes(for: inputNode)
        
        // Обрабатываем зависимые ноды
        for dependentNode in dependentNodes {
            processNode(dependentNode)
        }
    }
    
    /// Находит все ноды, которые зависят от данной ноды
    private func findDependentNodes(for sourceNode: BaseNode) -> [BaseNode] {
        var dependentNodes: [BaseNode] = []
        var visited: Set<UUID> = []
        
        func collectDependents(_ node: BaseNode) {
            guard !visited.contains(node.id) else { return }
            visited.insert(node.id)
            
            // Находим все соединения от этой ноды
            guard let nodeGraph = nodeGraph else { return }
            let outgoingConnections = nodeGraph.connections.filter { $0.fromNode == node.id }
            
            for connection in outgoingConnections {
                if let dependentNode = nodeGraph.nodes.first(where: { $0.id == connection.toNode }) {
                    dependentNodes.append(dependentNode)
                    collectDependents(dependentNode)
                }
            }
        }
        
        collectDependents(sourceNode)
        return dependentNodes
    }
    
    /// Топологическая сортировка нод для правильного порядка обработки
    private func topologicalSort() -> [BaseNode] {
        guard let nodeGraph = nodeGraph else { return [] }
        
        var sorted: [BaseNode] = []
        var visited: Set<UUID> = []
        var visiting: Set<UUID> = []
        
        func visit(_ node: BaseNode) {
            if visiting.contains(node.id) {
                // Обнаружен цикл - пропускаем
                return
            }
            
            if visited.contains(node.id) {
                return
            }
            
            visiting.insert(node.id)
            
            // Посещаем все input ноды сначала
            let inputConnections = nodeGraph.connections.filter { $0.toNode == node.id }
            for connection in inputConnections {
                if let inputNode = nodeGraph.nodes.first(where: { $0.id == connection.fromNode }) {
                    visit(inputNode)
                }
            }
            
            visiting.remove(node.id)
            visited.insert(node.id)
            sorted.append(node)
        }
        
        for node in nodeGraph.nodes {
            visit(node)
        }
        
        return sorted
    }
    
    /// Очищает устаревшие записи из кэша
    private func cleanupExpiredCache() {
        let now = Date()
        let expiredKeys = lastProcessTime.compactMap { (key, time) -> UUID? in
            return now.timeIntervalSince(time) > cacheExpirationTime ? key : nil
        }
        
        for key in expiredKeys {
            processCache.removeValue(forKey: key)
            lastProcessTime.removeValue(forKey: key)
        }
        
        // Ограничиваем размер кэша
        if processCache.count > maxCacheSize {
            let sortedByTime = lastProcessTime.sorted { $0.value < $1.value }
            let keysToRemove = sortedByTime.prefix(processCache.count - maxCacheSize).map { $0.key }
            
            for key in keysToRemove {
                processCache.removeValue(forKey: key)
                lastProcessTime.removeValue(forKey: key)
            }
        }
    }
    
    deinit {
        cancellables.removeAll()
        processCache.removeAll()
        lastProcessTime.removeAll()
        print("🗑️ NodeGraphProcessor deallocated")
    }
    
    /// Принудительно обновляет все ноды
    func forceRefresh() {
        invalidateCache()
        processGraph()
    }
    
    /// Очищает кэш обработки
    private func invalidateCache() {
        processCache.removeAll()
        lastProcessTime.removeAll()
    }
    
    /// Получает выходные данные определенной ноды
    func getOutput(for node: BaseNode) -> CIImage? {
        return processCache[node.id] ?? nil
    }
    
    /// Обработка видео тика для обновления видео нод
    func processVideoTick() {
        guard let nodeGraph = nodeGraph else { return }
        let videoNodes = nodeGraph.nodes.compactMap { $0 as? InputNode }.filter { $0.mediaType == .video && $0.isVideoPlaying }
        
        for videoNode in videoNodes {
            onInputNodeChanged(videoNode)
        }
    }
} 
