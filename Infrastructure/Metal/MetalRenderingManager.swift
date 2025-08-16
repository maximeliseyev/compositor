//
//  MetalRenderingManager.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 12.08.2025.
//

import SwiftUI
import Metal
import MetalKit

/// Глобальный менеджер Metal рендеринга для всего приложения
@MainActor
class MetalRenderingManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = MetalRenderingManager()
    
    // MARK: - Metal Components
    let renderer: MetalRenderer
    let textureManager: TextureManager
    
    // MARK: - Settings
    @Published var isMetalEnabled: Bool = true
    @Published var preferredRenderer: RendererType = .metal
    @Published var performanceMode: PerformanceMode = .balanced
    
    // MARK: - Statistics
    @Published var frameCount: Int = 0
    @Published var averageFrameTime: Double = 0.0
    @Published var gpuUtilization: Double = 0.0
    
    private var lastFrameTime: Date = Date()
    private var frameTimes: [Double] = []
    
    // MARK: - Initialization
    private init() {
        // Инициализируем Metal компоненты
        self.renderer = MetalRenderer()
        self.textureManager = renderer.textureManager
        
        // Настраиваем производительность
        setupPerformanceMode()
        
        print("🚀 Metal Rendering Manager initialized")
        print("📱 Device: \(renderer.device.name)")
        print("⚡ Performance Mode: \(performanceMode.rawValue)")
    }
    
    // MARK: - Performance Management
    
    enum PerformanceMode: String, CaseIterable {
        case powerSaving = "Power Saving"
        case balanced = "Balanced"
        case performance = "Performance"
        case ultra = "Ultra"
        
        var description: String {
            switch self {
            case .powerSaving:
                return "Optimized for battery life"
            case .balanced:
                return "Balanced performance and power"
            case .performance:
                return "Optimized for performance"
            case .ultra:
                return "Maximum performance"
            }
        }
        
        var maxFrameRate: Int {
            switch self {
            case .powerSaving: return 30
            case .balanced: return 60
            case .performance: return 120
            case .ultra: return 144
            }
        }
    }
    
    private func setupPerformanceMode() {
        // Настраиваем параметры в зависимости от режима производительности
        switch performanceMode {
        case .powerSaving:
            // Минимальное использование GPU
            break
        case .balanced:
            // Стандартные настройки
            break
        case .performance:
            // Увеличиваем кэширование
            break
        case .ultra:
            // Максимальные настройки
            break
        }
    }
    
    // MARK: - Node Creation
    
    /// Создает ноду с предпочтительным рендерером
    func createNode(type: NodeType, position: CGPoint) -> BaseNode {
        return NodeFactory.createNode(
            type: type,
            position: position,
            preferredRenderer: preferredRenderer
        )
    }
    
    /// Создает Metal ноду
    func createMetalNode(type: NodeType, position: CGPoint) -> BaseNode {
        return NodeFactory.createNode(
            type: type,
            position: position,
            preferredRenderer: .metal
        )
    }
    
    /// Создает Core Image ноду
    func createCoreImageNode(type: NodeType, position: CGPoint) -> BaseNode {
        return NodeFactory.createNode(
            type: type,
            position: position,
            preferredRenderer: .coreImage
        )
    }
    
    // MARK: - Rendering Control
    
    /// Включает/выключает Metal рендеринг
    func toggleMetalRendering() {
        isMetalEnabled.toggle()
        if isMetalEnabled {
            preferredRenderer = .metal
        } else {
            preferredRenderer = .coreImage
        }
        
        print("🔄 Metal rendering \(isMetalEnabled ? "enabled" : "disabled")")
    }
    
    /// Устанавливает режим производительности
    func setPerformanceMode(_ mode: PerformanceMode) {
        performanceMode = mode
        setupPerformanceMode()
        print("⚡ Performance mode set to: \(mode.rawValue)")
    }
    
    // MARK: - Statistics
    
    /// Обновляет статистику производительности
    func updateStatistics() {
        let currentTime = Date()
        let frameTime = currentTime.timeIntervalSince(lastFrameTime)
        lastFrameTime = currentTime
        
        frameCount += 1
        frameTimes.append(frameTime)
        
        // Ограничиваем количество измерений
        if frameTimes.count > 60 {
            frameTimes.removeFirst()
        }
        
        // Вычисляем среднее время кадра
        averageFrameTime = frameTimes.reduce(0, +) / Double(frameTimes.count)
        
        // Обновляем статистику GPU (упрощенная версия)
        updateGPUStatistics()
    }
    
    private func updateGPUStatistics() {
        // В реальном приложении здесь можно получить статистику GPU
        // через Metal Performance Shaders или другие API
        gpuUtilization = min(100.0, max(0.0, 100.0 - (averageFrameTime * 1000)))
    }
    
    // MARK: - Memory Management
    
    /// Очищает кэши и освобождает память
    func cleanupMemory() {
        textureManager.forceCleanup()
        print("🧹 Memory cleanup completed")
    }
    
    /// Получает информацию о памяти
    func getMemoryInfo() -> String {
        let stats = textureManager.getStatistics()
        return """
        📊 Memory Usage:
           Created: \(stats.totalCreated)
           Reused: \(stats.totalReused)
           In Use: \(stats.currentlyInUse)
           In Pool: \(stats.currentlyInPool)
           Reuse Ratio: \(String(format: "%.1f", stats.reuseRatio * 100))%
        """
    }
    
    // MARK: - Debug Information
    
    /// Получает полную информацию о системе
    func getSystemInfo() -> String {
        return """
        🖥️ System Information:
           Device: \(renderer.device.name)
           Metal Version: \(metalVersionString())
           Max Threads: \(renderer.device.maxThreadsPerThreadgroup)
           Memory: \(renderer.device.recommendedMaxWorkingSetSize / 1024 / 1024) MB
           Low Power: \(renderer.device.isLowPower ? "Yes" : "No")
           
        ⚡ Performance:
           Mode: \(performanceMode.rawValue)
           Max FPS: \(performanceMode.maxFrameRate)
           Average Frame Time: \(String(format: "%.2f", averageFrameTime * 1000))ms
           GPU Utilization: \(String(format: "%.1f", gpuUtilization))%
           
        🎯 Rendering:
           Metal Enabled: \(isMetalEnabled ? "Yes" : "No")
           Preferred Renderer: \(preferredRenderer.rawValue)
           Frame Count: \(frameCount)
        """
    }

    private func metalVersionString() -> String {
        let device = renderer.device
        if device.supportsFamily(MTLGPUFamily.mac2) { return "macOS GPU Family 2" }
        // Note: mac1 was deprecated in macOS 13.0, using mac2 as fallback
        return "macOS GPU Family 2+"
    }
}

// MARK: - Convenience Extensions

extension View {
    /// Применяет Metal рендеринг к view
    @MainActor func metalRendering() -> some View {
        self.environmentObject(MetalRenderingManager.shared)
    }
}

// MARK: - Environment Key

struct MetalRenderingManagerKey: EnvironmentKey {
    // Use MainActor.assumeIsolated to safely access the shared instance
    static let defaultValue: MetalRenderingManager = {
        MainActor.assumeIsolated {
            MetalRenderingManager.shared
        }
    }()
}

extension EnvironmentValues {
    var metalRenderingManager: MetalRenderingManager {
        get { self[MetalRenderingManagerKey.self] }
        set { self[MetalRenderingManagerKey.self] = newValue }
    }
}
