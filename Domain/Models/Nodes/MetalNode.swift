//
//  OptimizedMetalNode.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 12.08.2025.
//

import SwiftUI
import CoreImage
import Metal

// MARK: - Optimized Metal Renderer Protocol

protocol MetalRendererProtocol {
    var isReady: Bool { get }
    var conversionCount: Int { get }
    var cacheHitRate: Double { get }
    var averageProcessingTime: TimeInterval { get }
    
    func processImage(_ image: CIImage, withShader shaderName: String, parameters: [String: Any]) async throws -> CIImage?
    func processBatch(_ images: [CIImage], withShader shaderName: String, parameters: [String: Any]) async throws -> [CIImage?]
    func getPerformanceStats() -> String
}

// MARK: - Optimized Metal Node

/// Оптимизированный базовый класс для нод, использующих Metal рендеринг
/// Использует систему TextureData для минимизации конвертаций
class MetalNode: BaseNode {
    
    // MARK: - Metal Properties
    private var metalRenderer: MetalRendererProtocol?
    private var isMetalAvailable: Bool = false
    
    // MARK: - Processing Mode
    enum ProcessingMode {
        case coreImage    // Использовать Core Image
        case metal        // Использовать Metal
        case auto         // Автоматически выбирать лучший вариант
    }
    
    @Published var processingMode: ProcessingMode = .auto
    
    // MARK: - Performance Tracking
    @Published var metalProcessingTime: TimeInterval = 0.0
    @Published var conversionCount: Int = 0
    @Published var cacheHitRate: Double = 0.0
    
    // MARK: - Initialization
    override init(type: NodeType, position: CGPoint) {
        super.init(type: type, position: position)
        setupMetalRenderer()
    }
    
    // MARK: - Metal Setup
    private func setupMetalRenderer() {
        // Временно отключаем Metal рендерер до интеграции
        self.isMetalAvailable = false
        print("ℹ️ Optimized Metal renderer temporarily disabled")
    }
    
    // MARK: - Processing Override
    
    override func process(inputs: [CIImage?]) -> CIImage? {
        guard inputs.first != nil else {
            return nil
        }
        
        // Для синхронной обработки используем Core Image как fallback
        return processWithCoreImage(inputs: inputs)
    }
    
    override func processAsync(inputs: [CIImage?]) async throws -> CIImage? {
        switch processingMode {
        case .coreImage:
            return processWithCoreImage(inputs: inputs)
        case .metal:
            return try await processWithMetal(inputs: inputs)
        case .auto:
            return isMetalAvailable ? try await processWithMetal(inputs: inputs) : processWithCoreImage(inputs: inputs)
        }
    }
    
    // MARK: - Core Image Processing
    func processWithCoreImage(inputs: [CIImage?]) -> CIImage? {
        // Базовая реализация - просто возвращает входное изображение
        // Переопределяется в подклассах
        return inputs.first ?? nil
    }
    
    // MARK: - Optimized Metal Processing
    
    /// Асинхронная обработка через оптимизированный Metal без блокировки UI потока
    private func processWithMetal(inputs: [CIImage?]) async throws -> CIImage? {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Unwrap nested optionals safely
        guard let first = inputs.first else {
            print("⚠️ OptimizedMetalNode received empty inputs")
            return nil
        }
        guard let inputImage = first else {
            print("⚠️ OptimizedMetalNode received nil input image")
            return nil
        }
        guard let renderer = metalRenderer else {
            // Fallback to Core Image if Metal is not available
            print("ℹ️ Optimized Metal renderer not ready, using Core Image path")
            return processWithCoreImage(inputs: inputs)
        }
        
        // Асинхронная обработка без блокировки
        do {
            let result = try await processWithMetalShader(inputImage: inputImage, renderer: renderer)
            
            // Обновляем метрики производительности
            let processingTime = CFAbsoluteTimeGetCurrent() - startTime
            await updatePerformanceMetrics(renderer: renderer, processingTime: processingTime)
            
            return result
        } catch {
            print("⚠️ Falling back to Core Image due to Metal error: \(error)")
            return processWithCoreImage(inputs: inputs)
        }
    }
    
    // MARK: - Metal Shader Processing
    /// Переопределяется в подклассах для специфичной обработки
    func processWithMetalShader(inputImage: CIImage, renderer: MetalRendererProtocol) async throws -> CIImage? {
        // Базовая реализация - просто возвращает входное изображение
        // Переопределяется в подклассах для специфичной обработки
        return inputImage
    }
    
    // MARK: - Performance Monitoring
    
    @MainActor
    private func updatePerformanceMetrics(renderer: MetalRendererProtocol, processingTime: TimeInterval) {
        self.metalProcessingTime = processingTime
        self.conversionCount = renderer.conversionCount
        self.cacheHitRate = renderer.cacheHitRate
    }
    
    // MARK: - Utility Methods
    
    /// Получает параметры для Metal шейдера
    func getMetalParameters() -> [String: Any] {
        var params: [String: Any] = [:]
        
        // Добавляем базовые параметры
        for (key, value) in parameters {
            if let floatValue = value as? Float {
                params[key] = floatValue
            } else if let intValue = value as? Int {
                params[key] = Float(intValue)
            } else if let doubleValue = value as? Double {
                params[key] = Float(doubleValue)
            } else if let boolValue = value as? Bool {
                params[key] = boolValue ? 1.0 : 0.0
            }
        }
        
        return params
    }
    
    /// Проверяет доступность Metal
    func isMetalSupported() -> Bool {
        return isMetalAvailable && metalRenderer != nil
    }
    
    /// Получает информацию о производительности
    func getPerformanceInfo() -> String {
        if isMetalAvailable {
            return """
            Metal: Available
            Processing time: \(String(format: "%.3f", metalProcessingTime))s
            Conversions: \(conversionCount)
            Cache hit rate: \(String(format: "%.1f", cacheHitRate * 100))%
            """
        } else {
            return "Metal: Not available (using Core Image)"
        }
    }
}

