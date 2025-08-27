//
//  TextureData.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 12.08.2025.
//

import Foundation
@preconcurrency import CoreImage
@preconcurrency import Metal
@preconcurrency import MetalKit

// Импортируем TextureManager из того же модуля

// MARK: - Texture Data Protocol

/// Протокол для унифицированного представления текстурных данных
/// Позволяет избежать ненужных конвертаций между CIImage и MTLTexture
protocol TextureData: Sendable {
    /// Размеры изображения
    var extent: CGRect { get }
    
    /// Формат пикселей
    var pixelFormat: MTLPixelFormat { get }
    
    /// Ширина в пикселях
    var width: Int { get }
    
    /// Высота в пикселях
    var height: Int { get }
    
    /// Уникальный идентификатор для кэширования
    var cacheKey: String { get }
    
    /// Получает MTLTexture для Metal операций
    func getMetalTexture(device: MTLDevice) async throws -> MTLTexture
    
    /// Получает CIImage для Core Image операций
    func getCIImage() -> CIImage
    
    /// Проверяет, является ли текстура валидной
    var isValid: Bool { get }
    
    /// Освобождает ресурсы
    func release()
}

// MARK: - CIImage Texture Data

/// Реализация TextureData для CIImage
/// Лениво создает MTLTexture только при необходимости
class CIImageTextureData: @unchecked Sendable, @preconcurrency TextureData {
    private let ciImage: CIImage
    private var cachedTexture: MTLTexture?
    private let textureManager: TextureManager
    internal let cacheKey: String
    
    init(ciImage: CIImage, textureManager: TextureManager) {
        self.ciImage = ciImage
        self.textureManager = textureManager
        self.cacheKey = "CIImage_\(ciImage.extent.width)_\(ciImage.extent.height)_\(ciImage.hashValue)"
    }
    
    // MARK: - TextureData Protocol
    
    var extent: CGRect { ciImage.extent }
    var pixelFormat: MTLPixelFormat { .rgba8Unorm }
    var width: Int { Int(ciImage.extent.width) }
    var height: Int { Int(ciImage.extent.height) }
    var isValid: Bool { !ciImage.extent.isEmpty }
    
    func getCIImage() -> CIImage {
        return ciImage
    }
    
    func getMetalTexture(device: MTLDevice) async throws -> MTLTexture {
        // Возвращаем кэшированную текстуру, если она есть
        if let cached = cachedTexture {
            return cached
        }
        
        // Создаем новую текстуру
        guard let texture = await textureManager.acquireTexture(
            width: width,
            height: height,
            pixelFormat: pixelFormat
        ) else {
            throw TextureDataError.cannotCreateTexture
        }
        
        // Рендерим CIImage в текстуру
        let context = CIContext(mtlDevice: device, options: [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            .cacheIntermediates: false
        ])
        
        context.render(
            ciImage,
            to: texture,
            commandBuffer: nil,
            bounds: extent,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
        )
        
        // Кэшируем текстуру
        cachedTexture = texture
        
        return texture
    }
    
    @MainActor func release() {
        if let texture = cachedTexture {
            textureManager.releaseTexture(texture)
            cachedTexture = nil
        }
    }
}

// MARK: - MTLTexture Texture Data

/// Реализация TextureData для MTLTexture
/// Лениво создает CIImage только при необходимости
class MTLTextureData: @unchecked Sendable, @preconcurrency TextureData {
    private let texture: MTLTexture
    private var cachedCIImage: CIImage?
    internal let cacheKey: String
    
    init(texture: MTLTexture) {
        self.texture = texture
        self.cacheKey = "MTLTexture_\(texture.width)_\(texture.height)_\(ObjectIdentifier(texture))"
    }
    
    // MARK: - TextureData Protocol
    
    var extent: CGRect { 
        CGRect(x: 0, y: 0, width: texture.width, height: texture.height)
    }
    var pixelFormat: MTLPixelFormat { texture.pixelFormat }
    var width: Int { texture.width }
    var height: Int { texture.height }
    var isValid: Bool { texture.width > 0 && texture.height > 0 }
    
    func getMetalTexture(device: MTLDevice) async throws -> MTLTexture {
        return texture
    }
    
    func getCIImage() -> CIImage {
        // Возвращаем кэшированное CIImage, если оно есть
        if let cached = cachedCIImage {
            return cached
        }
        
        // Создаем новое CIImage
        let ciImage = CIImage(mtlTexture: texture, options: [
            .colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
        ]) ?? CIImage()
        
        // Кэшируем CIImage
        cachedCIImage = ciImage
        
        return ciImage
    }
    
    func release() {
        cachedCIImage = nil
        // Не освобождаем MTLTexture, так как он может использоваться в других местах
    }
}

// MARK: - Texture Data Factory

/// Фабрика для создания TextureData объектов
class TextureDataFactory {
    private let textureManager: TextureManager
    
    init(textureManager: TextureManager) {
        self.textureManager = textureManager
    }
    
    /// Создает TextureData из CIImage
    func createFromCIImage(_ ciImage: CIImage) -> TextureData {
        return CIImageTextureData(ciImage: ciImage, textureManager: textureManager)
    }
    
    /// Создает TextureData из MTLTexture
    func createFromMTLTexture(_ texture: MTLTexture) -> TextureData {
        return MTLTextureData(texture: texture)
    }
    
    /// Создает пустую TextureData
    func createEmpty(width: Int, height: Int, pixelFormat: MTLPixelFormat = .rgba8Unorm) async -> TextureData? {
        guard let texture = await textureManager.acquireTexture(
            width: width,
            height: height,
            pixelFormat: pixelFormat
        ) else {
            return nil
        }
        
        return MTLTextureData(texture: texture)
    }
}

// MARK: - Texture Data Cache

/// Кэш для TextureData объектов
class TextureDataCache {
    private var cache: [String: TextureData] = [:]
    private let maxCacheSize: Int
    private let queue = DispatchQueue(label: "TextureDataCache", qos: .userInitiated)
    
    init(maxCacheSize: Int = 50) {
        self.maxCacheSize = maxCacheSize
    }
    
    /// Получает TextureData из кэша
    func get(for key: String) -> TextureData? {
        return queue.sync {
            return cache[key]
        }
    }
    
    /// Добавляет TextureData в кэш
    func set(_ textureData: TextureData, for key: String) {
        queue.async {
            // Очищаем кэш, если он переполнен
            if self.cache.count >= self.maxCacheSize {
                self.cleanupCache()
            }
            
            self.cache[key] = textureData
        }
    }
    
    /// Удаляет TextureData из кэша
    func remove(for key: String) {
        queue.async {
            if let textureData = self.cache.removeValue(forKey: key) {
                textureData.release()
            }
        }
    }
    
    /// Очищает весь кэш
    func clear() {
        queue.async {
            for textureData in self.cache.values {
                textureData.release()
            }
            self.cache.removeAll()
        }
    }
    
    /// Получает размер кэша
    func getCacheSize() -> Int {
        return queue.sync {
            return cache.count
        }
    }
    
    /// Очищает старые записи из кэша
    private func cleanupCache() {
        // Простая стратегия: удаляем первые 20% записей
        let removeCount = max(1, cache.count / 5)
        let keysToRemove = Array(cache.keys.prefix(removeCount))
        
        for key in keysToRemove {
            if let textureData = cache.removeValue(forKey: key) {
                textureData.release()
            }
        }
    }
}

// MARK: - Error Definitions

enum TextureDataError: LocalizedError {
    case cannotCreateTexture
    case invalidTexture
    case conversionFailed
    
    var errorDescription: String? {
        switch self {
        case .cannotCreateTexture:
            return "Cannot create Metal texture"
        case .invalidTexture:
            return "Invalid texture data"
        case .conversionFailed:
            return "Failed to convert between texture formats"
        }
    }
}

// MARK: - Performance Constants

/// Константы производительности для TextureData
struct TextureDataConstants {
    /// Максимальный размер кэша текстур
    static let maxCacheSize = 50
    
    /// Время жизни кэшированной текстуры в секундах
    static let cacheLifetime: TimeInterval = 30.0
    
    /// Минимальный размер текстуры для кэширования
    static let minCacheSize = CGSize(width: 64, height: 64)
}
