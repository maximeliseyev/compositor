//
//  TextureManager.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 12.08.2025.
//


import Foundation
import Metal

class TextureManager {
    
    private let device: MTLDevice
    
    // Pool текстур для переиспользования
    private var texturePool: [TextureKey: [MTLTexture]] = [:]
    private var usedTextures: [MTLTexture] = []
    
    // Настройки пула
    private let maxPoolSize = 10
    private let cleanupInterval: TimeInterval = 30.0
    private var lastCleanup = Date()
    
    // Статистика
    private var totalCreated = 0
    private var totalReused = 0
    
    init(device: MTLDevice) {
        self.device = device
        print("🏗️ TextureManager initialized")
    }
    
    // MARK: - Public Interface
    
    func acquireTexture(
        width: Int,
        height: Int,
        pixelFormat: MTLPixelFormat = .rgba8Unorm,
        usage: MTLTextureUsage = [.shaderRead, .shaderWrite, .renderTarget]
    ) -> MTLTexture? {
        
        let key = TextureKey(width: width, height: height, pixelFormat: pixelFormat)
        
        // Пытаемся получить из пула
        if var availableTextures = texturePool[key],
           !availableTextures.isEmpty {
            let texture = availableTextures.removeFirst()
            texturePool[key] = availableTextures
            usedTextures.append(texture)
            totalReused += 1
            
            print("♻️ Reused texture: \(width)x\(height) (\(pixelFormat))")
            return texture
        }
        
        // Создаем новую текстуру
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = usage
        descriptor.storageMode = .private // Оптимально для GPU
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            print("❌ Failed to create texture: \(width)x\(height)")
            return nil
        }
        
        usedTextures.append(texture)
        totalCreated += 1
        
        print("🆕 Created texture: \(width)x\(height) (\(pixelFormat))")
        return texture
    }
    
    func releaseTexture(_ texture: MTLTexture) {
        guard let index = usedTextures.firstIndex(where: { $0 === texture }) else {
            print("⚠️ Trying to release texture that wasn't acquired")
            return
        }
        
        usedTextures.remove(at: index)
        
        let key = TextureKey(
            width: texture.width,
            height: texture.height,
            pixelFormat: texture.pixelFormat
        )
        
        // Добавляем в пул если есть место
        if texturePool[key] == nil {
            texturePool[key] = []
        }
        
        if let poolTextures = texturePool[key], poolTextures.count < maxPoolSize {
            texturePool[key]?.append(texture)
            print("🔄 Texture returned to pool: \(texture.width)x\(texture.height)")
        } else {
            print("🗑️ Texture discarded (pool full): \(texture.width)x\(texture.height)")
        }
        
        // Периодическая очистка
        cleanupIfNeeded()
    }
    
    // MARK: - Pool Management
    
    private func cleanupIfNeeded() {
        let now = Date()
        if now.timeIntervalSince(lastCleanup) > cleanupInterval {
            cleanup()
            lastCleanup = now
        }
    }
    
    func cleanup() {
        var totalFreed = 0
        
        for key in texturePool.keys {
            if let textures = texturePool[key], textures.count > maxPoolSize / 2 {
                let keepCount = maxPoolSize / 2
                let freeCount = textures.count - keepCount
                texturePool[key] = Array(textures.prefix(keepCount))
                totalFreed += freeCount
            }
        }
        
        if totalFreed > 0 {
            print("🧹 Cleaned up \(totalFreed) textures from pool")
        }
    }
    
    func forceCleanup() {
        texturePool.removeAll()
        usedTextures.removeAll()
        totalCreated = 0
        totalReused = 0
        print("🧹 Force cleanup: All textures released")
    }
    
    // MARK: - Statistics and Monitoring
    
    func getStatistics() -> TextureManagerStats {
        var currentlyInPool = 0
        for (_, textures) in texturePool {
            currentlyInPool += textures.count
        }
        
        let reuseRatio = totalCreated > 0 ? Double(totalReused) / Double(totalCreated + totalReused) : 0.0
        
        return TextureManagerStats(
            totalCreated: totalCreated,
            totalReused: totalReused,
            currentlyInUse: usedTextures.count,
            currentlyInPool: currentlyInPool,
            reuseRatio: reuseRatio
        )
    }
    
    func getMemoryUsage() -> Int {
        var totalBytes = 0
        
        // Calculate memory for used textures
        for texture in usedTextures {
            totalBytes += estimateTextureSize(texture)
        }
        
        // Calculate memory for pooled textures
        for (_, textures) in texturePool {
            for texture in textures {
                totalBytes += estimateTextureSize(texture)
            }
        }
        
        return totalBytes
    }
    
    private func estimateTextureSize(_ texture: MTLTexture) -> Int {
        let bytesPerPixel = texture.pixelFormat.bytesPerPixel
        return texture.width * texture.height * bytesPerPixel
    }
    
    func printStatistics() {
        let stats = getStatistics()
        print("""
        📊 TextureManager Statistics:
           Created: \(stats.totalCreated)
           Reused: \(stats.totalReused)
           In Use: \(stats.currentlyInUse)
           In Pool: \(stats.currentlyInPool)
           Reuse Ratio: \(String(format: "%.1f", stats.reuseRatio * 100))%
        """)
    }
    
    deinit {
        forceCleanup()
        print("🗑️ TextureManager deallocated")
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

struct TextureManagerStats {
    let totalCreated: Int
    let totalReused: Int
    let currentlyInUse: Int
    let currentlyInPool: Int
    let reuseRatio: Double
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