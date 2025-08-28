//
//  CoreImageNode.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 14.07.2025.
//

import SwiftUI
import CoreImage

// MARK: - Core Image Node

/// Базовый класс для нод, использующих Core Image фильтры
/// Оптимизирован для стандартных эффектов без необходимости Metal
class CoreImageNode: BaseNode {
    
    // MARK: - Core Image Properties
    private let context = CIContext()
    
    // MARK: - Performance Tracking
    @Published var coreImageProcessingTime: TimeInterval = 0.0
    @Published var filterCacheHits: Int = 0
    @Published var totalProcessingCount: Int = 0
    
    // MARK: - Filter Cache
    private var filterCache: [String: CIFilter] = [:]
    
    // MARK: - Initialization
    override init(type: NodeType, position: CGPoint) {
        super.init(type: type, position: position)
        setupCoreImageNode()
    }
    
    // MARK: - Setup
    private func setupCoreImageNode() {
        // Инициализация специфичная для Core Image нод
        print("🖼️ CoreImageNode initialized for type: \(type.rawValue)")
    }
    
    // MARK: - Core Image Processing Override
    
    override func process(inputs: [CIImage?]) -> CIImage? {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let result = processWithCoreImage(inputs: inputs)
        
        // Обновляем метрики производительности
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        updatePerformanceMetrics(processingTime: processingTime)
        
        return result
    }
    
    override func processAsync(inputs: [CIImage?]) async throws -> CIImage? {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Выполняем обработку в фоновом потоке
        let result = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let processedResult = self.processWithCoreImage(inputs: inputs)
                continuation.resume(returning: processedResult)
            }
        }
        
        // Обновляем метрики производительности
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        updatePerformanceMetrics(processingTime: processingTime)
        
        return result
    }
    
    // MARK: - Core Image Processing
    
    /// Основной метод обработки через Core Image
    /// Переопределяется в подклассах для специфичной обработки
    func processWithCoreImage(inputs: [CIImage?]) -> CIImage? {
        // Базовая реализация - просто возвращает входное изображение
        // Переопределяется в подклассах
        return inputs.first ?? nil
    }
    
    // MARK: - Filter Management
    
    /// Создает или получает кэшированный фильтр
    func getOrCreateFilter(name: String) -> CIFilter? {
        if let cachedFilter = filterCache[name] {
            filterCacheHits += 1
            return cachedFilter
        }
        
        let filter = CIFilter(name: name)
        if filter != nil {
            filterCache[name] = filter
        }
        
        return filter
    }
    
    /// Очищает кэш фильтров
    func clearFilterCache() {
        filterCache.removeAll()
    }
    
    // MARK: - Performance Monitoring
    
    private func updatePerformanceMetrics(processingTime: TimeInterval) {
        self.coreImageProcessingTime = processingTime
        self.totalProcessingCount += 1
    }
    
    // MARK: - Utility Methods
    
    /// Получает параметры для Core Image фильтра
    func getCoreImageParameters() -> [String: Any] {
        var params: [String: Any] = [:]
        
        // Добавляем базовые параметры с правильными типами для Core Image
        for (key, value) in parameters {
            if let floatValue = value as? Float {
                params[key] = NSNumber(value: floatValue)
            } else if let intValue = value as? Int {
                params[key] = NSNumber(value: intValue)
            } else if let doubleValue = value as? Double {
                params[key] = NSNumber(value: doubleValue)
            } else if let boolValue = value as? Bool {
                params[key] = NSNumber(value: boolValue)
            } else {
                params[key] = value
            }
        }
        
        return params
    }
    
    /// Получает информацию о производительности
    func getPerformanceInfo() -> String {
        let cacheHitRate = totalProcessingCount > 0 ? 
            Double(filterCacheHits) / Double(totalProcessingCount) : 0.0
        
        return """
        Core Image: Active
        Processing time: \(String(format: "%.3f", coreImageProcessingTime))s
        Total operations: \(totalProcessingCount)
        Cache hit rate: \(String(format: "%.1f", cacheHitRate * 100))%
        """
    }
    
    // MARK: - Cache Invalidation
    
    override func invalidateCache() {
        super.invalidateCache()
        // Очищаем кэш фильтров при изменении параметров
        clearFilterCache()
    }
}
