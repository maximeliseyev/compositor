//
//  NodeGraphProcessor.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 12.08.2025.
//

import Foundation
import CoreImage
import Combine

// MARK: - Node Graph Processor

/// Процессор для асинхронной обработки графа нод
@MainActor
class NodeGraphProcessor: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isProcessing: Bool = false
    @Published var processingProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var activeNodeCount: Int = 0
    
    // MARK: - Private Properties
    
    private let nodeGraph: NodeGraph
    private var processingTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // Performance tracking
    private var processingTimes: [TimeInterval] = []
    private var lastProcessingTime: Date = Date()
    
    // MARK: - Initialization
    
    init(nodeGraph: NodeGraph) {
        self.nodeGraph = nodeGraph
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Автоматическая обработка при изменениях в графе
        // TODO: Добавить наблюдение за изменениями в NodeGraph
    }
    
    // MARK: - Public Methods
    
    /// Запускает обработку графа нод
    func processGraph() async {
        guard !isProcessing else { return }
        
        isProcessing = true
        processingProgress = 0.0
        errorMessage = nil
        activeNodeCount = 0
        
        let startTime = Date()
        
        do {
            // Проверяем на циклы
            if nodeGraph.hasCycles() {
                errorMessage = "Cycle detected in node graph"
                isProcessing = false
                return
            }
            
            // Получаем топологическую сортировку
            let sortedNodes = nodeGraph.getTopologicalSort()
            activeNodeCount = sortedNodes.count
            
            // Обрабатываем ноды в правильном порядке
            for (index, node) in sortedNodes.enumerated() {
                processingProgress = Double(index) / Double(sortedNodes.count)
                
                // Обрабатываем ноду
                await processNode(node)
                
                // Небольшая задержка для UI
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
            
            processingProgress = 1.0
            errorMessage = nil
            
            // Обновляем статистику производительности
            let processingTime = Date().timeIntervalSince(startTime)
            processingTimes.append(processingTime)
            
            // Ограничиваем количество измерений
            if processingTimes.count > 10 {
                processingTimes.removeFirst()
            }
            
        } catch {
            errorMessage = "Processing error: \(error.localizedDescription)"
        }
        
        isProcessing = false
        activeNodeCount = 0
    }
    
    /// Останавливает обработку
    func stopProcessing() async {
        processingTask?.cancel()
        isProcessing = false
        activeNodeCount = 0
    }
    
    /// Приостанавливает обработку
    func pauseProcessing() async {
        // TODO: Реализовать приостановку
        print("⏸️ Processing paused")
    }
    
    /// Возобновляет обработку
    func resumeProcessing() async {
        // TODO: Реализовать возобновление
        print("▶️ Processing resumed")
    }
    
    // MARK: - Private Methods
    
    private func processNode(_ node: BaseNode) async {
        // Здесь должна быть логика обработки конкретной ноды
        // Например, рендеринг, применение фильтров и т.д.
        print("⚙️ Processing node: \(node.type.rawValue)")
        
        // Имитация обработки
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
    }
    
    // MARK: - Performance Monitoring
    
    /// Получает среднее время обработки
    var averageProcessingTime: TimeInterval {
        guard !processingTimes.isEmpty else { return 0 }
        return processingTimes.reduce(0, +) / Double(processingTimes.count)
    }
    
    /// Получает максимальное время обработки
    var maxProcessingTime: TimeInterval {
        return processingTimes.max() ?? 0
    }
    
    /// Получает минимальное время обработки
    var minProcessingTime: TimeInterval {
        return processingTimes.min() ?? 0
    }
    
    // MARK: - Cleanup
    
    deinit {
        processingTask?.cancel()
        cancellables.removeAll()
    }
}
