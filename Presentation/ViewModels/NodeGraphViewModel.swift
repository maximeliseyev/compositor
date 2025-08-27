//
//  NodeGraphViewModel.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 12.08.2025.
//

import Foundation
import SwiftUI
import CoreImage
import Combine

// MARK: - Node Graph ViewModel

/// ViewModel для управления графом нод с асинхронной обработкой
@MainActor
class NodeGraphViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var nodes: [BaseNode] = []
    @Published var connections: [NodeConnection] = []
    @Published var selectedNodes: Set<UUID> = []
    @Published var isProcessing: Bool = false
    @Published var processingProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var activeNodeCount: Int = 0
    
    // MARK: - Private Properties
    
    private let nodeGraph: NodeGraph
    private let processor: NodeGraphProcessor
    private var cancellables = Set<AnyCancellable>()
    private var syncTimer: Timer?
    
    // Performance tracking
    private var lastProcessingTime: Date = Date()
    private var processingTimes: [TimeInterval] = []
    
    // MARK: - Initialization
    
    init(nodeGraph: NodeGraph) {
        self.nodeGraph = nodeGraph
        self.processor = NodeGraphProcessor(nodeGraph: nodeGraph)
        setupBindings()
        setupPerformanceMonitoring()
        setupProcessorBindings()
        setupDataSync()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Автоматическая обработка при изменениях
        Publishers.CombineLatest($nodes, $connections)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _ in
                Task { @MainActor in
                    await self?.processGraphIfNeeded()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupDataSync() {
        // Синхронизируем данные с NodeGraph каждые 100ms
        syncTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.syncDataFromNodeGraph()
            }
        }
    }
    
    private func setupProcessorBindings() {
        // Подписка на состояние процессора
        processor.$isProcessing
            .receive(on: DispatchQueue.main)
            .assign(to: &$isProcessing)
        
        processor.$processingProgress
            .receive(on: DispatchQueue.main)
            .assign(to: &$processingProgress)
        
        processor.$errorMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &$errorMessage)
        
        processor.$activeNodeCount
            .receive(on: DispatchQueue.main)
            .assign(to: &$activeNodeCount)
    }
    
    private func setupPerformanceMonitoring() {
        // Обновление статистики каждые 2 секунды
        Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updatePerformanceStats()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Synchronization
    
    private func syncDataFromNodeGraph() {
        // Синхронизируем ноды по ID
        let currentNodeIds = Set(nodes.map { $0.id })
        let graphNodeIds = Set(nodeGraph.nodes.map { $0.id })
        
        if currentNodeIds != graphNodeIds {
            nodes = nodeGraph.nodes
        }
        
        // Синхронизируем соединения
        if connections != nodeGraph.connections {
            connections = nodeGraph.connections
        }
    }
    
    // MARK: - Public Methods
    
    /// Добавляет ноду в граф
    func addNode(_ node: BaseNode) {
        nodeGraph.addNode(node)
        
        // Логирование для отладки
        print("➕ Added node: \(node.type.rawValue) at \(node.position)")
    }
    
    /// Удаляет ноду из графа
    func removeNode(_ node: BaseNode) {
        // Убираем из выделенных
        selectedNodes.remove(node.id)
        
        nodeGraph.removeNode(node)
        
        print("➖ Removed node: \(node.type.rawValue)")
    }
    
    /// Перемещает ноду
    func moveNode(_ node: BaseNode, to position: CGPoint) {
        nodeGraph.moveNode(node, to: position)
    }
    
    /// Создает соединение между портами
    func connectPorts(
        fromNode: BaseNode,
        fromPort: NodePort,
        toNode: BaseNode,
        toPort: NodePort
    ) -> Bool {
        let success = nodeGraph.connectPorts(
            fromNode: fromNode,
            fromPort: fromPort,
            toNode: toNode,
            toPort: toPort
        )
        
        if success {
            print("🔗 Connected \(fromNode.type.rawValue) to \(toNode.type.rawValue)")
        } else {
            print("❌ Failed to connect \(fromNode.type.rawValue) to \(toNode.type.rawValue)")
        }
        
        return success
    }
    
    /// Удаляет соединение
    func removeConnection(_ connection: NodeConnection) {
        // Используем централизованный метод из NodeGraph
        nodeGraph.removeConnection(connection)
        
        print("🔌 Removed connection")
    }
    
    /// Выбирает ноду
    func selectNode(_ node: BaseNode) {
        selectedNodes.insert(node.id)
    }
    
    /// Отменяет выбор ноды
    func deselectNode(_ node: BaseNode) {
        selectedNodes.remove(node.id)
    }
    
    /// Очищает выбор
    func clearSelection() {
        selectedNodes.removeAll()
    }
    
    /// Выбирает несколько нод
    func selectNodes(_ nodes: [BaseNode]) {
        selectedNodes = Set(nodes.map { $0.id })
    }
    
    // MARK: - Processing
    
    private func processGraphIfNeeded() async {
        guard !nodes.isEmpty else { return }
        
        // Проверяем на циклы
        if nodeGraph.hasCycles() {
            errorMessage = "Cycle detected in node graph"
            return
        }
        
        // Запускаем обработку через процессор
        await processor.processGraph()
    }
    
    /// Принудительно запускает обработку графа
    func startProcessing() async {
        await processor.processGraph()
    }
    
    /// Останавливает обработку графа
    func stopProcessing() async {
        await processor.stopProcessing()
    }
    
    /// Приостанавливает обработку графа
    func pauseProcessing() async {
        await processor.pauseProcessing()
    }
    
    /// Возобновляет обработку графа
    func resumeProcessing() async {
        await processor.resumeProcessing()
    }
    
    // MARK: - Performance Monitoring
    
    private func updatePerformanceStats() {
        let averageTime = processor.averageProcessingTime
        let maxTime = processor.maxProcessingTime
        let minTime = processor.minProcessingTime
        
        print("📊 Performance Stats:")
        print("   Average processing time: \(String(format: "%.2f", averageTime * 1000))ms")
        print("   Max processing time: \(String(format: "%.2f", maxTime * 1000))ms")
        print("   Min processing time: \(String(format: "%.2f", minTime * 1000))ms")
        print("   Node count: \(nodes.count)")
        print("   Connection count: \(connections.count)")
        print("   Active nodes: \(activeNodeCount)")
    }
    
    // MARK: - Utility Methods
    
    /// Получает информацию о производительности
    func getPerformanceInfo() -> String {
        let averageTime = processor.averageProcessingTime
        
        return """
        📊 Performance Information:
           Average Processing Time: \(String(format: "%.3f", averageTime))s
           Active Nodes: \(activeNodeCount)
           Processing Progress: \(String(format: "%.1f", processingProgress * 100))%
           Total Nodes: \(nodes.count)
           Total Connections: \(connections.count)
           Selected Nodes: \(selectedNodes.count)
        """
    }
    
    /// Получает статистику кэша
    func getCacheStats() -> String {
        // Здесь можно добавить статистику кэша из asyncProcessor
        return "Cache statistics available through async processor"
    }
    
    // MARK: - Cleanup
    
    deinit {
        syncTimer?.invalidate()
        cancellables.removeAll()
    }
}
