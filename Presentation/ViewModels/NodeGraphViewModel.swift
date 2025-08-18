import Foundation
import SwiftUI
import CoreImage
import Combine

// MARK: - Node Graph ViewModel

/// ViewModel для управления графом нод (упрощенная версия для демонстрации архитектуры)
@MainActor
class NodeGraphViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var nodes: [BaseNode] = []
    @Published var connections: [NodeConnection] = []
    @Published var selectedNodes: Set<UUID> = []
    @Published var isProcessing: Bool = false
    @Published var processingProgress: Double = 0.0
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let nodeGraph: NodeGraph
    private var cancellables = Set<AnyCancellable>()
    
    // Performance tracking
    private var lastProcessingTime: Date = Date()
    private var processingTimes: [TimeInterval] = []
    
    // MARK: - Initialization
    
    init(nodeGraph: NodeGraph = NodeGraph()) {
        self.nodeGraph = nodeGraph
        setupBindings()
        setupPerformanceMonitoring()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Подписка на изменения в графе нод
        nodeGraph.$nodes
            .receive(on: DispatchQueue.main)
            .assign(to: &$nodes)
        
        nodeGraph.$connections
            .receive(on: DispatchQueue.main)
            .assign(to: &$connections)
        
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
    
    private func setupPerformanceMonitoring() {
        // Обновление статистики каждые 2 секунды
        Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updatePerformanceStats()
            }
            .store(in: &cancellables)
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
            print("🔗 Connected: \(fromNode.type.rawValue).\(fromPort.name) → \(toNode.type.rawValue).\(toPort.name)")
        } else {
            errorMessage = "Failed to connect ports: incompatible types or would create cycle"
        }
        
        return success
    }
    
    /// Удаляет соединение
    func removeConnection(_ connection: NodeConnection) {
        nodeGraph.removeConnection(connection)
        print("🔓 Removed connection")
    }
    
    /// Выделяет/снимает выделение с ноды
    func toggleNodeSelection(_ nodeId: UUID) {
        if selectedNodes.contains(nodeId) {
            selectedNodes.remove(nodeId)
        } else {
            selectedNodes.insert(nodeId)
        }
    }
    
    /// Очищает выделение
    func clearSelection() {
        selectedNodes.removeAll()
    }
    
    /// Выделяет все ноды
    func selectAll() {
        selectedNodes = Set(nodes.map { $0.id })
    }
    
    /// Удаляет выделенные ноды
    func deleteSelectedNodes() {
        let nodesToDelete = nodes.filter { selectedNodes.contains($0.id) }
        for node in nodesToDelete {
            removeNode(node)
        }
        clearSelection()
    }
    
    // MARK: - Processing
    
    /// Обрабатывает граф нод (упрощенная версия)
    func processGraph() async {
        guard !isProcessing else { return }
        
        isProcessing = true
        processingProgress = 0.0
        errorMessage = nil
        
        let startTime = Date()
        
        do {
            // Простая обработка графа
            processingProgress = 0.2
            
            // Симуляция обработки
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 секунды
            
            processingProgress = 1.0
            
            // Обновляем статистику времени
            let processingTime = Date().timeIntervalSince(startTime)
            updateProcessingTime(processingTime)
            
            print("✅ Graph processed successfully in \(String(format: "%.2f", processingTime))s")
            
        } catch {
            errorMessage = "Processing failed: \(error.localizedDescription)"
            print("❌ Graph processing failed: \(error)")
        }
        
        isProcessing = false
    }
    
    /// Обрабатывает граф при необходимости (с дебаунсом)
    private func processGraphIfNeeded() async {
        // Обрабатываем только если есть ноды и соединения
        guard !nodes.isEmpty else { return }
        
        await processGraph()
    }
    
    // MARK: - Performance Monitoring
    
    private func updatePerformanceStats() {
        // Упрощенная версия без внешних зависимостей
        print("📊 Performance stats updated")
    }
    
    private func updateProcessingTime(_ time: TimeInterval) {
        processingTimes.append(time)
        
        // Ограничиваем количество записей
        if processingTimes.count > 10 {
            processingTimes.removeFirst()
        }
    }
    
    /// Получает среднее время обработки
    var averageProcessingTime: TimeInterval {
        guard !processingTimes.isEmpty else { return 0 }
        return processingTimes.reduce(0, +) / Double(processingTimes.count)
    }
    
    // MARK: - Memory Management
    
    /// Очищает память и кэши
    func cleanupMemory() {
        // Упрощенная версия
        print("🧹 Memory cleanup requested")
    }
    
    // MARK: - Debug Information
    
    /// Получает информацию для отладки
    func getDebugInfo() -> String {
        return """
        📊 Node Graph Debug Info:
           Nodes: \(nodes.count)
           Connections: \(connections.count)
           Selected: \(selectedNodes.count)
           Processing: \(isProcessing ? "Yes" : "No")
           Avg Processing Time: \(String(format: "%.2f", averageProcessingTime))s
        """
    }
    
    deinit {
        cancellables.removeAll()
        print("🗑️ NodeGraphViewModel deallocated")
    }
}

// MARK: - Factory Methods

extension NodeGraphViewModel {
    
    /// Создает ноду указанного типа
    func createNode(type: NodeType, at position: CGPoint) -> BaseNode {
        let node = BaseNode(type: type, position: position)
        addNode(node)
        return node
    }
    
    /// Дублирует выделенные ноды
    func duplicateSelectedNodes() {
        let nodesToDuplicate = nodes.filter { selectedNodes.contains($0.id) }
        clearSelection()
        
        for node in nodesToDuplicate {
            let duplicatedNode = BaseNode(
                type: node.type,
                position: CGPoint(x: node.position.x + 50, y: node.position.y + 50)
            )
            
            // Копируем параметры
            duplicatedNode.parameters = node.parameters
            
            addNode(duplicatedNode)
            selectedNodes.insert(duplicatedNode.id)
        }
    }
}

// MARK: - Keyboard Shortcuts Support

extension NodeGraphViewModel {
    
    /// Обрабатывает команды клавиатуры
    func handleKeyCommand(_ command: KeyCommand) {
        switch command {
        case .delete:
            deleteSelectedNodes()
        case .selectAll:
            selectAll()
        case .duplicate:
            duplicateSelectedNodes()
        case .processGraph:
            Task {
                await processGraph()
            }
        case .cleanupMemory:
            cleanupMemory()
        }
    }
}

enum KeyCommand {
    case delete
    case selectAll
    case duplicate
    case processGraph
    case cleanupMemory
}
