//
//  OptimizedMetalRenderer.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 12.08.2025.
//

import Foundation
@preconcurrency import Metal
@preconcurrency import MetalKit
import SwiftUI
@preconcurrency import CoreImage

/// Оптимизированный Metal рендерер с системой TextureData
/// Минимизирует конвертации между CIImage и MTLTexture
class OptimizedMetalRenderer: ObservableObject, @unchecked Sendable {
    
    // MARK: - Metal Properties
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    
    // MARK: - Pipeline Cache
    private var renderPipelineCache: [String: MTLRenderPipelineState] = [:]
    private var computePipelineCache: [String: MTLComputePipelineState] = [:]
    
    // MARK: - Texture Management
    let textureManager: TextureManager
    let textureDataFactory: TextureDataFactory
    let textureDataCache: TextureDataCache
    
    // MARK: - Published Properties
    @Published var isReady = false
    @Published var errorMessage: String?
    
    // MARK: - Performance Metrics
    @Published var conversionCount: Int = 0
    @Published var cacheHitRate: Double = 0.0
    @Published var averageProcessingTime: TimeInterval = 0.0
    
    private var totalConversions = 0
    private var totalCacheHits = 0
    private var totalCacheMisses = 0
    private var processingTimes: [TimeInterval] = []
    
    private init(device: MTLDevice, commandQueue: MTLCommandQueue, library: MTLLibrary, textureManager: TextureManager) {
        self.device = device
        self.commandQueue = commandQueue
        self.library = library
        self.textureManager = textureManager
        self.textureDataFactory = TextureDataFactory(textureManager: textureManager)
        self.textureDataCache = TextureDataCache(maxCacheSize: TextureDataConstants.maxCacheSize)
        
        self.isReady = true
        
        print("✅ Optimized Metal initialized successfully")
        print("📱 Device: \(device.name)")
        print("🔧 Max threads per group: \(device.maxThreadsPerThreadgroup)")
    }
    
    /// Создает новый экземпляр OptimizedMetalRenderer асинхронно
    static func create() async -> OptimizedMetalRenderer? {
        // Проверяем доступность Metal
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("❌ Metal not supported on this device")
            return nil
        }
        
        guard let commandQueue = device.makeCommandQueue() else {
            print("❌ Could not create Metal command queue")
            return nil
        }
        
        // Пытаемся загрузить шейдеры
        guard let library = device.makeDefaultLibrary() else {
            print("❌ Could not load Metal shaders library")
            return nil
        }
        
        let textureManager = await TextureManager(device: device)
        return OptimizedMetalRenderer(device: device, commandQueue: commandQueue, library: library, textureManager: textureManager)
    }
    
    // MARK: - Optimized Processing Interface
    
    /// Оптимизированная обработка изображения через Metal шейдер
    /// Использует TextureData для минимизации конвертаций
    func processImageOptimized(_ inputImage: CIImage, withShader shaderName: String, parameters: [String: Any] = [:]) async throws -> CIImage? {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Создаем TextureData из CIImage
        let inputTextureData = textureDataFactory.createFromCIImage(inputImage)
        
        // Проверяем кэш
        let cacheKey = "\(shaderName)_\(inputTextureData.cacheKey)_\(String(describing: parameters).hashValue)"
        if let cachedResult = textureDataCache.get(for: cacheKey) {
            totalCacheHits += 1
            updateMetrics(processingTime: CFAbsoluteTimeGetCurrent() - startTime)
            return cachedResult.getCIImage()
        }
        
        totalCacheMisses += 1
        
        // Обрабатываем через Metal
        let outputTextureData = try await processTextureDataOptimized(
            inputTextureData: inputTextureData,
            shaderName: shaderName,
            parameters: parameters
        )
        
        // Кэшируем результат
        textureDataCache.set(outputTextureData, for: cacheKey)
        
        // Получаем CIImage для возврата
        let result = outputTextureData.getCIImage()
        
        updateMetrics(processingTime: CFAbsoluteTimeGetCurrent() - startTime)
        
        return result
    }
    
    /// Обрабатывает TextureData через Metal шейдер
    /// Избегает ненужных конвертаций
    private func processTextureDataOptimized(
        inputTextureData: TextureData,
        shaderName: String,
        parameters: [String: Any]
    ) async throws -> TextureData {
        
        // Получаем MTLTexture для Metal операций
        let inputTexture = try await inputTextureData.getMetalTexture(device: device)
        
        // Создаем выходную текстуру
        guard let outputTexture = await textureManager.acquireTexture(
            width: inputTextureData.width,
            height: inputTextureData.height,
            pixelFormat: inputTextureData.pixelFormat
        ) else {
            throw MetalError.cannotCreateTexture
        }
        
        // Применяем шейдер
        try await applyComputeShaderOptimized(
            shaderName: shaderName,
            inputTexture: inputTexture,
            outputTexture: outputTexture,
            parameters: parameters
        )
        
        // Создаем TextureData из выходной текстуры
        let outputTextureData = textureDataFactory.createFromMTLTexture(outputTexture)
        
        return outputTextureData
    }
    
    /// Применяет compute шейдер к текстурам (оптимизированная версия)
    private func applyComputeShaderOptimized(
        shaderName: String,
        inputTexture: MTLTexture,
        outputTexture: MTLTexture,
        parameters: [String: Any]
    ) async throws {
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw MetalError.cannotCreateCommandBuffer
        }
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalError.cannotCreateEncoder
        }
        
        let pipelineState = try getComputePipelineState(for: shaderName)
        computeEncoder.setComputePipelineState(pipelineState)
        
        // Устанавливаем текстуры
        computeEncoder.setTexture(inputTexture, index: 0)
        computeEncoder.setTexture(outputTexture, index: 1)
        
        // Устанавливаем параметры
        if let params = parameters as? [String: Float] {
            for (key, value) in params {
                if let index = getParameterIndex(for: key) {
                    var floatValue = value
                    computeEncoder.setBytes(&floatValue, length: MemoryLayout<Float>.size, index: index)
                }
            }
        }
        
        // Вычисляем размеры thread groups
        let threadGroupSize = MTLSizeMake(16, 16, 1)
        let threadGroups = MTLSizeMake(
            (inputTexture.width + threadGroupSize.width - 1) / threadGroupSize.width,
            (inputTexture.height + threadGroupSize.height - 1) / threadGroupSize.height,
            1
        )
        
        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        computeEncoder.endEncoding()
        
        // Выполняем команды
        commandBuffer.commit()
        
        // Ждем завершения
        return try await withCheckedThrowingContinuation { continuation in
            commandBuffer.addCompletedHandler { _ in
                continuation.resume()
            }
        }
    }
    
    // MARK: - Batch Processing
    
    /// Обрабатывает несколько изображений пакетно
    /// Максимально эффективно использует GPU
    func processBatchOptimized(_ images: [CIImage], withShader shaderName: String, parameters: [String: Any] = [:]) async throws -> [CIImage?] {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Создаем TextureData для всех изображений
        let inputTextureDataArray = images.map { textureDataFactory.createFromCIImage($0) }
        
        // Обрабатываем пакетно
        let results = try await withThrowingTaskGroup(of: (Int, TextureData?).self) { group in
            for (index, inputTextureData) in inputTextureDataArray.enumerated() {
                group.addTask {
                    let result = try await self.processTextureDataOptimized(
                        inputTextureData: inputTextureData,
                        shaderName: shaderName,
                        parameters: parameters
                    )
                    return (index, result)
                }
            }
            
            var outputArray: [TextureData?] = Array(repeating: nil, count: images.count)
            for try await (index, result) in group {
                outputArray[index] = result
            }
            return outputArray
        }
        
        // Конвертируем обратно в CIImage
        let ciImageResults = results.map { $0?.getCIImage() }
        
        updateMetrics(processingTime: CFAbsoluteTimeGetCurrent() - startTime)
        
        return ciImageResults
    }
    
    // MARK: - Pipeline Management
    
    func getRenderPipelineState(for functionName: String) throws -> MTLRenderPipelineState {
        if let cached = renderPipelineCache[functionName] {
            return cached
        }
        
        guard let function = library.makeFunction(name: functionName) else {
            throw MetalError.functionNotFound(functionName)
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = function
        pipelineDescriptor.fragmentFunction = function
        pipelineDescriptor.colorAttachments[0].pixelFormat = .rgba8Unorm
        
        let pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        renderPipelineCache[functionName] = pipelineState
        
        print("🔨 Created render pipeline: \(functionName)")
        return pipelineState
    }
    
    func getComputePipelineState(for functionName: String) throws -> MTLComputePipelineState {
        if let cached = computePipelineCache[functionName] {
            return cached
        }
        
        guard let function = library.makeFunction(name: functionName) else {
            throw MetalError.functionNotFound(functionName)
        }
        
        let pipelineState = try device.makeComputePipelineState(function: function)
        computePipelineCache[functionName] = pipelineState
        
        print("🔨 Created compute pipeline: \(functionName)")
        return pipelineState
    }
    
    // MARK: - Performance Monitoring
    
    private func updateMetrics(processingTime: TimeInterval) {
        DispatchQueue.main.async {
            self.processingTimes.append(processingTime)
            
            // Ограничиваем размер массива
            if self.processingTimes.count > 100 {
                self.processingTimes.removeFirst()
            }
            
            // Обновляем метрики
            self.averageProcessingTime = self.processingTimes.reduce(0, +) / Double(self.processingTimes.count)
            self.conversionCount = self.totalConversions
            
            let totalCacheAccesses = self.totalCacheHits + self.totalCacheMisses
            if totalCacheAccesses > 0 {
                self.cacheHitRate = Double(self.totalCacheHits) / Double(totalCacheAccesses)
            }
        }
    }
    
    /// Получает статистику производительности
    func getPerformanceStats() -> String {
        return """
        📊 Optimized Metal Performance Stats:
        🔄 Total conversions: \(totalConversions)
        🎯 Cache hit rate: \(String(format: "%.1f", cacheHitRate * 100))%
        ⏱️ Average processing time: \(String(format: "%.3f", averageProcessingTime))s
        💾 Cache size: \(textureDataCache.getCacheSize())
        """
    }
    
    // MARK: - Utility Methods
    
    private func getParameterIndex(for key: String) -> Int? {
        // Маппинг параметров на индексы буферов
        let parameterMap: [String: Int] = [
            "radius": 0,
            "intensity": 1,
            "threshold": 2,
            "blurType": 3
        ]
        return parameterMap[key]
    }
    
    /// Очищает кэш и освобождает ресурсы
    func cleanup() {
        textureDataCache.clear()
        renderPipelineCache.removeAll()
        computePipelineCache.removeAll()
        
        print("🧹 Optimized Metal renderer cleaned up")
    }
}

// MARK: - Error Definitions
// MetalError уже определен в MetalRenderer.swift
