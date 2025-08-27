//
//  TextureManager.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 12.08.2025.
//

import Foundation
@preconcurrency import Metal
import Combine
import SwiftUI

/// Улучшенный менеджер текстур с оптимизированным пулом и асинхронной обработкой
class TextureManager: ObservableObject {
    
    // MARK: - Configuration
    private struct Configuration {
        static let maxPoolSize = PerformanceConstants.maxTexturePoolSize
        static let maxMemoryMB = PerformanceConstants.maxTextureMemoryMB
        static let cleanupInterval: TimeInterval = PerformanceConstants.textureCleanupInterval
        static let preloadCount = PerformanceConstants.texturePreloadCount
        static let memoryThreshold = PerformanceConstants.memoryPressureThreshold
        static let textureLifetime: TimeInterval = PerformanceConstants.textureLifetime
        static let priorityTextures = PerformanceConstants.priorityTexturesCount
    }
    
    // MARK: - Texture Priority
    enum TexturePriority: Int, CaseIterable {
        case low = 0
        case normal = 1
        case high = 2
        case critical = 3
        
        var poolSize: Int {
            switch self {
            case .low: return Configuration.maxPoolSize / 4
            case .normal: return Configuration.maxPoolSize / 2
            case .high: return Configuration.maxPoolSize / 4
            case .critical: return Configuration.priorityTextures
            }
        }
    }
    
    // MARK: - Properties
    private let device: MTLDevice
    private let queue = DispatchQueue(label: "compositor.texturemanager", qos: .userInitiated)
    
    // Пул текстур с приоритизацией
    private var texturePools: [TextureKey: [TextureEntry]] = [:]
    private var usedTextures: [MTLTexture] = []
    private var textureCreationTimes: [ObjectIdentifier: Date] = [:]
    private var texturePriorities: [ObjectIdentifier: TexturePriority] = [:]
    
    // Мониторинг памяти и производительности
    private var currentMemoryUsage: Int64 = 0
    private var peakMemoryUsage: Int64 = 0
    private var memoryPressureLevel: Float = 0.0
    
    // Статистика и метрики
    private var totalCreated = 0
    private var totalReused = 0
    private var totalDiscarded = 0
    private var lastCleanup = Date()
    
    // Асинхронная обработка
    private var cleanupTask: Task<Void, Never>?
    private var preloadTask: Task<Void, Never>?
    private var monitoringTask: Task<Void, Never>?
    
    // Публикуемые свойства для UI
    @Published var isPreloading = false
    @Published var memoryUsageMB: Double = 0.0
    @Published var poolSize: Int = 0
    @Published var reuseRatio: Double = 0.0
    @Published var memoryPressure: Float = 0.0
    
    // MARK: - Initialization
    init(device: MTLDevice) {
        self.device = device
        print("🏗️ Enhanced TextureManager initialized")
        
        // Запускаем фоновые задачи
        startBackgroundCleanup()
        startMemoryMonitoring()
        preloadCommonTextures()
    }
    
    // MARK: - Public Interface
    
    /// Асинхронно получает текстуру из пула или создает новую
    func acquireTexture(
        width: Int,
        height: Int,
        pixelFormat: MTLPixelFormat = .rgba8Unorm,
        usage: MTLTextureUsage = [.shaderRead, .shaderWrite, .renderTarget],
        priority: TexturePriority = .normal
    ) async -> MTLTexture? {
        
        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else { return }
                let texture = self._acquireTexture(
                    width: width,
                    height: height,
                    pixelFormat: pixelFormat,
                    usage: usage,
                    priority: priority
                )
                continuation.resume(returning: texture)
            }
        }
    }
    
    /// Синхронная версия для совместимости
    func acquireTextureSync(
        width: Int,
        height: Int,
        pixelFormat: MTLPixelFormat = .rgba8Unorm,
        usage: MTLTextureUsage = [.shaderRead, .shaderWrite, .renderTarget]
    ) -> MTLTexture? {
        
        return queue.sync {
            return _acquireTexture(
                width: width,
                height: height,
                pixelFormat: pixelFormat,
                usage: usage,
                priority: .normal
            )
        }
    }
    
    /// Освобождает текстуру обратно в пул
    func releaseTexture(_ texture: MTLTexture) {
        queue.async {
            self._releaseTexture(texture)
        }
    }
    
    /// Устанавливает приоритет для текстуры
    func setTexturePriority(_ texture: MTLTexture, priority: TexturePriority) {
        queue.async {
            self.texturePriorities[ObjectIdentifier(texture)] = priority
        }
    }
    
    /// Принудительная очистка всех текстур
    func forceCleanup() {
        queue.async {
            self._forceCleanup()
        }
    }
    
    /// Адаптивная очистка на основе давления памяти
    func adaptiveCleanup() {
        queue.async {
            self._adaptiveCleanup()
        }
    }
    
    /// Получает статистику использования
    func getStatistics() -> TextureManagerStats {
        return queue.sync {
            return self._getStatistics()
        }
    }
    
    // MARK: - Private Implementation
    
    private func _acquireTexture(
        width: Int,
        height: Int,
        pixelFormat: MTLPixelFormat,
        usage: MTLTextureUsage,
        priority: TexturePriority
    ) -> MTLTexture? {
        
        let key = TextureKey(width: width, height: height, pixelFormat: pixelFormat)
        
        // Проверяем пул с приоритизацией
        if let texture = _getTextureFromPool(key: key, priority: priority) {
            return texture
        }
        
        // Проверяем лимиты памяти и выполняем адаптивную очистку
        let estimatedSize = Int64(width * height * pixelFormat.bytesPerPixel)
        if currentMemoryUsage + estimatedSize > Int64(Configuration.maxMemoryMB * 1024 * 1024) {
            print("⚠️ Memory limit reached, performing adaptive cleanup")
            _adaptiveCleanup()
        }
        
        // Создаем новую текстуру
        let texture = _createTexture(
            width: width,
            height: height,
            pixelFormat: pixelFormat,
            usage: usage,
            priority: priority
        )
        
        if let texture = texture {
            texturePriorities[ObjectIdentifier(texture)] = priority
        }
        
        return texture
    }
    
    private func _getTextureFromPool(key: TextureKey, priority: TexturePriority) -> MTLTexture? {
        guard var entries = texturePools[key] else { return nil }
        
        // Ищем текстуру с подходящим приоритетом
        for (index, entry) in entries.enumerated() {
            if entry.priority.rawValue >= priority.rawValue {
                let texture = entry.texture
                entries.remove(at: index)
                texturePools[key] = entries
                
                usedTextures.append(texture)
                textureCreationTimes[ObjectIdentifier(texture)] = Date()
                totalReused += 1
                
                print("♻️ Reused texture: \(key.description) (priority: \(priority))")
                return texture
            }
        }
        
        return nil
    }
    
    private func _createTexture(
        width: Int,
        height: Int,
        pixelFormat: MTLPixelFormat,
        usage: MTLTextureUsage,
        priority: TexturePriority
    ) -> MTLTexture? {
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = usage
        descriptor.storageMode = .private
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            print("❌ Failed to create texture: \(width)x\(height)")
            return nil
        }
        
        let estimatedSize = Int64(width * height * pixelFormat.bytesPerPixel)
        
        usedTextures.append(texture)
        textureCreationTimes[ObjectIdentifier(texture)] = Date()
        currentMemoryUsage += estimatedSize
        peakMemoryUsage = max(peakMemoryUsage, currentMemoryUsage)
        totalCreated += 1
        
        // Обновляем UI
        Task { @MainActor in
            self.memoryUsageMB = Double(self.currentMemoryUsage) / (1024.0 * 1024.0)
            self.reuseRatio = self.totalCreated > 0 ? Double(self.totalReused) / Double(self.totalCreated + self.totalReused) : 0.0
        }
        
        print("🆕 Created texture: \(width)x\(height) (\(pixelFormat)) - \(String(format: "%.1f", Double(estimatedSize) / (1024.0 * 1024.0)))MB (priority: \(priority))")
        return texture
    }
    
    private func _releaseTexture(_ texture: MTLTexture) {
        guard let index = usedTextures.firstIndex(where: { $0 === texture }) else {
            print("⚠️ Trying to release texture that wasn't acquired")
            return
        }
        
        usedTextures.remove(at: index)
        let priority = texturePriorities[ObjectIdentifier(texture)] ?? .normal
        textureCreationTimes.removeValue(forKey: ObjectIdentifier(texture))
        texturePriorities.removeValue(forKey: ObjectIdentifier(texture))
        
        let key = TextureKey(
            width: texture.width,
            height: texture.height,
            pixelFormat: texture.pixelFormat
        )
        
        let textureSize = Int64(texture.width * texture.height * texture.pixelFormat.bytesPerPixel)
        currentMemoryUsage -= textureSize
        
        // Добавляем в пул с приоритизацией
        _addToPool(texture: texture, key: key, priority: priority)
        
        // Обновляем UI
        Task { @MainActor in
            self.memoryUsageMB = Double(self.currentMemoryUsage) / (1024.0 * 1024.0)
            self.poolSize = self._getPoolSize()
        }
        
        // Периодическая очистка
        _cleanupIfNeeded()
    }
    
    private func _addToPool(texture: MTLTexture, key: TextureKey, priority: TexturePriority) {
        if texturePools[key] == nil {
            texturePools[key] = []
        }
        
        let entry = TextureEntry(texture: texture, priority: priority, timestamp: Date())
        
        if let poolEntries = texturePools[key] {
            let maxPoolSize = priority.poolSize
            
            if poolEntries.count < maxPoolSize {
                texturePools[key]?.append(entry)
                print("🔄 Texture returned to pool: \(key.description) (priority: \(priority))")
            } else {
                // Удаляем самую старую текстуру с низким приоритетом
                if let oldestIndex = _findOldestLowPriorityEntry(entries: poolEntries) {
                    texturePools[key]?.remove(at: oldestIndex)
                    texturePools[key]?.append(entry)
                    print("🔄 Replaced old texture in pool: \(key.description)")
                } else {
                    totalDiscarded += 1
                    print("🗑️ Texture discarded (pool full): \(key.description)")
                }
            }
        }
    }
    
    private func _findOldestLowPriorityEntry(entries: [TextureEntry]) -> Int? {
        var oldestIndex: Int?
        var oldestTime = Date.distantFuture
        
        for (index, entry) in entries.enumerated() {
            if entry.priority == .low && entry.timestamp < oldestTime {
                oldestTime = entry.timestamp
                oldestIndex = index
            }
        }
        
        return oldestIndex
    }
    
    private func _adaptiveCleanup() {
        let memoryUsageRatio = Float(currentMemoryUsage) / Float(Configuration.maxMemoryMB * 1024 * 1024)
        
        if memoryUsageRatio > Float(Configuration.memoryThreshold) {
            // Агрессивная очистка
            _cleanup(aggressive: true, preservePriority: .critical)
        } else if memoryUsageRatio > Float(0.6) {
            // Умеренная очистка
            _cleanup(aggressive: false, preservePriority: .high)
        } else {
            // Легкая очистка
            _cleanup(aggressive: false, preservePriority: .normal)
        }
        
        memoryPressureLevel = memoryUsageRatio
        
        Task { @MainActor in
            self.memoryPressure = memoryUsageRatio
        }
    }
    
    private func _cleanup(aggressive: Bool = false, preservePriority: TexturePriority = .normal) {
        var totalFreed = 0
        
        // Очищаем старые текстуры из пула
        for key in texturePools.keys {
            if var entries = texturePools[key] {
                let now = Date()
                
                // Фильтруем текстуры по приоритету и времени жизни
                entries = entries.filter { entry in
                    let isOld = now.timeIntervalSince(entry.timestamp) > Configuration.textureLifetime
                    let shouldPreserve = entry.priority.rawValue >= preservePriority.rawValue
                    
                    if aggressive && isOld && !shouldPreserve {
                        let textureSize = Int64(entry.texture.width * entry.texture.height * entry.texture.pixelFormat.bytesPerPixel)
                        currentMemoryUsage -= textureSize
                        totalDiscarded += 1
                        return false
                    }
                    
                    return true
                }
                
                let freed = texturePools[key]!.count - entries.count
                texturePools[key] = entries
                totalFreed += freed
            }
        }
        
        if totalFreed > 0 {
            print("🧹 Adaptive cleanup: freed \(totalFreed) textures (pressure: \(String(format: "%.1f", memoryPressureLevel * 100))%)")
            
            Task { @MainActor in
                self.memoryUsageMB = Double(self.currentMemoryUsage) / (1024.0 * 1024.0)
                self.poolSize = self._getPoolSize()
            }
        }
    }
    
    private func _cleanupIfNeeded() {
        let now = Date()
        if now.timeIntervalSince(lastCleanup) > Configuration.cleanupInterval {
            _adaptiveCleanup()
            lastCleanup = now
        }
    }
    
    private func _forceCleanup() {
        texturePools.removeAll()
        usedTextures.removeAll()
        textureCreationTimes.removeAll()
        texturePriorities.removeAll()
        currentMemoryUsage = 0
        totalCreated = 0
        totalReused = 0
        totalDiscarded = 0
        memoryPressureLevel = 0.0
        
        Task { @MainActor in
            self.memoryUsageMB = 0.0
            self.poolSize = 0
            self.reuseRatio = 0.0
            self.memoryPressure = 0.0
        }
        
        print("🧹 Force cleanup: All textures released")
    }
    
    private func _getStatistics() -> TextureManagerStats {
        let currentlyInPool = _getPoolSize()
        let reuseRatio = totalCreated > 0 ? Double(totalReused) / Double(totalCreated + totalReused) : 0.0
        
        return TextureManagerStats(
            totalCreated: totalCreated,
            totalReused: totalReused,
            totalDiscarded: totalDiscarded,
            currentlyInUse: usedTextures.count,
            currentlyInPool: currentlyInPool,
            reuseRatio: reuseRatio,
            memoryUsageMB: Double(currentMemoryUsage) / (1024.0 * 1024.0),
            peakMemoryUsageMB: Double(peakMemoryUsage) / (1024.0 * 1024.0),
            memoryPressure: memoryPressureLevel
        )
    }
    
    private func _getPoolSize() -> Int {
        var count = 0
        for (_, entries) in texturePools {
            count += entries.count
        }
        return count
    }
    
    // MARK: - Background Tasks
    
    private func startBackgroundCleanup() {
        cleanupTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Configuration.cleanupInterval * 1_000_000_000))
                if !Task.isCancelled {
                    await MainActor.run {
                        self._cleanupIfNeeded()
                    }
                }
            }
        }
    }
    
    private func startMemoryMonitoring() {
        monitoringTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(5 * 1_000_000_000)) // Каждые 5 секунд
                if !Task.isCancelled {
                    await MainActor.run {
                        self._updateMemoryPressure()
                    }
                }
            }
        }
    }
    
    private func _updateMemoryPressure() {
        let memoryUsageRatio = Float(currentMemoryUsage) / Float(Configuration.maxMemoryMB * 1024 * 1024)
        
        if memoryUsageRatio > Float(0.9) {
            print("🚨 High memory pressure detected: \(String(format: "%.1f", memoryUsageRatio * 100))%")
            _adaptiveCleanup()
        }
        
        memoryPressureLevel = memoryUsageRatio
        
        Task { @MainActor in
            self.memoryPressure = memoryUsageRatio
        }
    }
    
    private func preloadCommonTextures() {
        preloadTask = Task {
            await MainActor.run {
                self.isPreloading = true
            }
            
            // Предварительно создаем популярные размеры с приоритетами
            let commonSizes = [
                (PerformanceConstants.fullHDWidth, PerformanceConstants.fullHDHeight, TexturePriority.high),   // Full HD
                (PerformanceConstants.hdWidth, PerformanceConstants.hdHeight, TexturePriority.high),           // HD
                (PerformanceConstants.fourKWidth, PerformanceConstants.fourKHeight, TexturePriority.normal),   // 4K
                (PerformanceConstants.twoKWidth, PerformanceConstants.twoKHeight, TexturePriority.normal),     // 2K
                (PerformanceConstants.lowResWidth, PerformanceConstants.lowResHeight, TexturePriority.low)     // 540p
            ]
            
            for (width, height, priority) in commonSizes {
                for _ in 0..<Configuration.preloadCount {
                    if let texture = await acquireTexture(
                        width: width,
                        height: height,
                        priority: priority
                    ) {
                        releaseTexture(texture)
                    }
                }
            }
            
            await MainActor.run {
                self.isPreloading = false
            }
            
            print("📦 Preloaded \(commonSizes.count * Configuration.preloadCount) common textures with priorities")
        }
    }
    
    // MARK: - Deinitialization
    
    deinit {
        cleanupTask?.cancel()
        preloadTask?.cancel()
        monitoringTask?.cancel()
        print("🗑️ Enhanced TextureManager deallocated")
    }
}

// MARK: - Supporting Types

struct TextureKey: Hashable {
    let width: Int
    let height: Int
    let pixelFormat: MTLPixelFormat
    
    var description: String {
        return "\(width)x\(height)_\(pixelFormat)"
    }
}

struct TextureEntry {
    let texture: MTLTexture
    let priority: TextureManager.TexturePriority
    let timestamp: Date
}

struct TextureManagerStats {
    let totalCreated: Int
    let totalReused: Int
    let totalDiscarded: Int
    let currentlyInUse: Int
    let currentlyInPool: Int
    let reuseRatio: Double
    let memoryUsageMB: Double
    let peakMemoryUsageMB: Double
    let memoryPressure: Float
}

// MARK: - Extensions

extension MTLTexture {
    var sizeInMB: Double {
        let bytesPerPixel = pixelFormat.bytesPerPixel
        let totalBytes = width * height * bytesPerPixel
        return Double(totalBytes) / (1024.0 * 1024.0)
    }
    
    var description: String {
        return "\(width)x\(height) \(pixelFormat) (\(String(format: "%.1f", sizeInMB))MB)"
    }
}

extension MTLPixelFormat {
    var bytesPerPixel: Int {
        switch self {
        case .rgba8Unorm, .bgra8Unorm, .rgba8Unorm_srgb:
            return 4
        case .rgba16Float:
            return 8
        case .rgba32Float:
            return 16
        case .r8Unorm:
            return 1
        case .rg8Unorm:
            return 2
        default:
            return 4 // Default assumption
        }
    }
}
