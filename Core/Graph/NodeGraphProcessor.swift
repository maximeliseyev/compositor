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
    private var nodeGraph: NodeGraph
    private var cancellables = Set<AnyCancellable>()
    
    // Кэш обработанных данных для избежания повторных вычислений
    private var processCache: [UUID: CIImage?] = [:]
    private var lastProcessTime: [UUID: Date] = [:]
    
    init(nodeGraph: NodeGraph) {
        self.nodeGraph = nodeGraph
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
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
        // Получаем все ноды в топологическом порядке
        let sortedNodes = topologicalSort()
        
        // Обрабатываем ноды в правильном порядке
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
                return sourceNode.processWithCache(inputs: getInputsForNode(sourceNode))
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
        let videoNodes = nodeGraph.nodes.compactMap { $0 as? InputNode }.filter { $0.mediaType == .video && $0.isVideoPlaying }
        
        for videoNode in videoNodes {
            onInputNodeChanged(videoNode)
        }
    }
} 
