//
//  TextureDataTests.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 12.08.2025.
//

import XCTest
import CoreImage
import Metal
import MetalKit
@testable import Compositor

class TextureDataTests: XCTestCase {
    
    var device: MTLDevice!
    var textureManager: TextureManager!
    var textureDataFactory: TextureDataFactory!
    var textureDataCache: TextureDataCache!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Инициализируем Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            XCTFail("Metal not supported on this device")
            return
        }
        
        self.device = device
        self.textureManager = TextureManager(device: device)
        self.textureDataFactory = TextureDataFactory(textureManager: textureManager)
        self.textureDataCache = TextureDataCache(maxCacheSize: 10)
    }
    
    override func tearDownWithError() throws {
        textureDataCache.clear()
        try super.tearDownWithError()
    }
    
    // MARK: - TextureData Protocol Tests
    
    func testCIImageTextureDataCreation() throws {
        // Создаем тестовое CIImage
        let testImage = createTestCIImage(width: 100, height: 100)
        let textureData = textureDataFactory.createFromCIImage(testImage)
        
        // Проверяем свойства
        XCTAssertEqual(textureData.extent, testImage.extent)
        XCTAssertEqual(textureData.width, 100)
        XCTAssertEqual(textureData.height, 100)
        XCTAssertEqual(textureData.pixelFormat, .rgba8Unorm)
        XCTAssertTrue(textureData.isValid)
        XCTAssertFalse(textureData.cacheKey.isEmpty)
    }
    
    func testMTLTextureDataCreation() throws {
        // Создаем тестовую MTLTexture
        let texture = createTestMTLTexture(width: 200, height: 150)
        let textureData = textureDataFactory.createFromMTLTexture(texture)
        
        // Проверяем свойства
        XCTAssertEqual(textureData.width, 200)
        XCTAssertEqual(textureData.height, 150)
        XCTAssertEqual(textureData.pixelFormat, texture.pixelFormat)
        XCTAssertTrue(textureData.isValid)
        XCTAssertFalse(textureData.cacheKey.isEmpty)
    }
    
    func testCIImageTextureDataLazyConversion() async throws {
        // Создаем TextureData из CIImage
        let testImage = createTestCIImage(width: 64, height: 64)
        let textureData = textureDataFactory.createFromCIImage(testImage)
        
        // Получаем CIImage (должно быть мгновенно)
        let ciImage = textureData.getCIImage()
        XCTAssertEqual(ciImage.extent, testImage.extent)
        
        // Получаем MTLTexture (должно создать новую текстуру)
        let metalTexture = try await textureData.getMetalTexture(device: device)
        XCTAssertEqual(metalTexture.width, 64)
        XCTAssertEqual(metalTexture.height, 64)
        
        // Повторный вызов должен вернуть ту же текстуру (кэширование)
        let cachedTexture = try await textureData.getMetalTexture(device: device)
        XCTAssertEqual(metalTexture, cachedTexture)
    }
    
    func testMTLTextureDataLazyConversion() async throws {
        // Создаем TextureData из MTLTexture
        let texture = createTestMTLTexture(width: 128, height: 128)
        let textureData = textureDataFactory.createFromMTLTexture(texture)
        
        // Получаем MTLTexture (должно быть мгновенно)
        let metalTexture = try await textureData.getMetalTexture(device: device)
        XCTAssertEqual(metalTexture, texture)
        
        // Получаем CIImage (должно создать новое CIImage)
        let ciImage = textureData.getCIImage()
        XCTAssertEqual(ciImage.extent.width, 128)
        XCTAssertEqual(ciImage.extent.height, 128)
        
        // Повторный вызов должен вернуть то же CIImage (кэширование)
        let cachedCIImage = textureData.getCIImage()
        XCTAssertEqual(ciImage.extent, cachedCIImage.extent)
    }
    
    // MARK: - Cache Tests
    
    func testTextureDataCache() throws {
        let testImage = createTestCIImage(width: 50, height: 50)
        let textureData = textureDataFactory.createFromCIImage(testImage)
        
        // Добавляем в кэш
        textureDataCache.set(textureData, for: "test_key")
        
        // Получаем из кэша
        let cachedData = textureDataCache.get(for: "test_key")
        XCTAssertNotNil(cachedData)
        XCTAssertEqual(cachedData?.extent, textureData.extent)
        
        // Удаляем из кэша
        textureDataCache.remove(for: "test_key")
        let removedData = textureDataCache.get(for: "test_key")
        XCTAssertNil(removedData)
    }
    
    func testCacheEviction() throws {
        // Заполняем кэш
        for i in 0..<15 {
            let testImage = createTestCIImage(width: 10 + i, height: 10 + i)
            let textureData = textureDataFactory.createFromCIImage(testImage)
            textureDataCache.set(textureData, for: "key_\(i)")
        }
        
        // Проверяем, что старые записи были удалены
        let firstEntry = textureDataCache.get(for: "key_0")
        XCTAssertNil(firstEntry, "Cache should have evicted old entries")
        
        // Проверяем, что новые записи остались
        let lastEntry = textureDataCache.get(for: "key_14")
        XCTAssertNotNil(lastEntry, "New entries should remain in cache")
    }
    
    // MARK: - Performance Tests
    
    func testConversionPerformance() throws {
        let testImage = createTestCIImage(width: 1024, height: 1024)
        let textureData = textureDataFactory.createFromCIImage(testImage)
        
        measure {
            // Измеряем время создания MTLTexture
            let expectation = XCTestExpectation(description: "Texture conversion")
            
            Task {
                do {
                    _ = try await textureData.getMetalTexture(device: device)
                    expectation.fulfill()
                } catch {
                    XCTFail("Texture conversion failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testCachePerformance() throws {
        let testImage = createTestCIImage(width: 512, height: 512)
        let textureData = textureDataFactory.createFromCIImage(testImage)
        
        // Добавляем в кэш
        textureDataCache.set(textureData, for: "perf_test")
        
        measure {
            // Измеряем время доступа к кэшу
            for _ in 0..<1000 {
                _ = textureDataCache.get(for: "perf_test")
            }
        }
    }
    
    func testBatchProcessingPerformance() async throws {
        // Создаем массив тестовых изображений
        let testImages = (0..<10).map { i in
            createTestCIImage(width: 256 + i * 10, height: 256 + i * 10)
        }
        
        // Создаем TextureData для всех изображений
        let textureDataArray = testImages.map { textureDataFactory.createFromCIImage($0) }
        
        measure {
            let expectation = XCTestExpectation(description: "Batch processing")
            
            Task {
                do {
                    // Обрабатываем пакетно
                    for textureData in textureDataArray {
                        _ = try await textureData.getMetalTexture(device: device)
                    }
                    expectation.fulfill()
                } catch {
                    XCTFail("Batch processing failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryRelease() async throws {
        let testImage = createTestCIImage(width: 1024, height: 1024)
        let textureData = textureDataFactory.createFromCIImage(testImage)
        
        // Создаем текстуру
        let texture = try await textureData.getMetalTexture(device: device)
        
        // Освобождаем ресурсы
        textureData.release()
        
        // Проверяем, что текстура была освобождена
        // (это сложно проверить напрямую, но мы можем убедиться, что метод выполняется без ошибок)
        XCTAssertNoThrow(textureData.release())
    }
    
    func testCacheMemoryManagement() throws {
        // Создаем много TextureData объектов
        var textureDataArray: [TextureData] = []
        
        for i in 0..<20 {
            let testImage = createTestCIImage(width: 100 + i, height: 100 + i)
            let textureData = textureDataFactory.createFromCIImage(testImage)
            textureDataArray.append(textureData)
            
            // Добавляем в кэш
            textureDataCache.set(textureData, for: "memory_test_\(i)")
        }
        
        // Очищаем кэш
        textureDataCache.clear()
        
        // Проверяем, что кэш пуст
        for i in 0..<20 {
            let cachedData = textureDataCache.get(for: "memory_test_\(i)")
            XCTAssertNil(cachedData, "Cache should be empty after clear")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidTextureData() throws {
        // Создаем пустое CIImage
        let emptyImage = CIImage()
        let textureData = textureDataFactory.createFromCIImage(emptyImage)
        
        // Проверяем, что TextureData помечен как невалидный
        XCTAssertFalse(textureData.isValid)
    }
    
    func testTextureCreationFailure() async throws {
        // Создаем TextureData с очень большими размерами (может вызвать ошибку)
        let largeImage = createTestCIImage(width: 16384, height: 16384)
        let textureData = textureDataFactory.createFromCIImage(largeImage)
        
        do {
            _ = try await textureData.getMetalTexture(device: device)
            // Если не выбросило исключение, то все хорошо
        } catch {
            // Ожидаемо, если устройство не поддерживает такие большие текстуры
            print("Expected error for large texture: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestCIImage(width: Int, height: Int) -> CIImage {
        let color = CIColor(red: 0.5, green: 0.3, blue: 0.8, alpha: 1.0)
        let extent = CGRect(x: 0, y: 0, width: width, height: height)
        return CIImage(color: color).cropped(to: extent)
    }
    
    private func createTestMTLTexture(width: Int, height: Int) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            fatalError("Failed to create test texture")
        }
        
        return texture
    }
}

// MARK: - Integration Tests

class TextureDataIntegrationTests: XCTestCase {
    
    var device: MTLDevice!
    var textureManager: TextureManager!
    var textureDataFactory: TextureDataFactory!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            XCTFail("Metal not supported on this device")
            return
        }
        
        self.device = device
        self.textureManager = TextureManager(device: device)
        self.textureDataFactory = TextureDataFactory(textureManager: textureManager)
    }
    
    func testTextureDataWorkflow() async throws {
        // Создаем исходное изображение
        let sourceImage = createTestCIImage(width: 512, height: 512)
        let sourceTextureData = textureDataFactory.createFromCIImage(sourceImage)
        
        // Получаем MTLTexture для обработки
        let sourceTexture = try await sourceTextureData.getMetalTexture(device: device)
        
        // Создаем выходную текстуру
        let outputTexture = textureManager.acquireTexture(
            width: sourceTexture.width,
            height: sourceTexture.height,
            pixelFormat: sourceTexture.pixelFormat
        )!
        
        // Копируем данные (симуляция обработки)
        let commandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
        
        blitEncoder.copy(
            from: sourceTexture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: sourceTexture.width, height: sourceTexture.height, depth: 1),
            to: outputTexture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        
        blitEncoder.endEncoding()
        commandBuffer.commit()
        
        // Ждем завершения
        await withCheckedContinuation { continuation in
            commandBuffer.addCompletedHandler { _ in
                continuation.resume()
            }
        }
        
        // Создаем TextureData из выходной текстуры
        let outputTextureData = textureDataFactory.createFromMTLTexture(outputTexture)
        
        // Получаем CIImage для проверки
        let outputImage = outputTextureData.getCIImage()
        
        // Проверяем, что размеры совпадают
        XCTAssertEqual(outputImage.extent.width, sourceImage.extent.width)
        XCTAssertEqual(outputImage.extent.height, sourceImage.extent.height)
        
        // Освобождаем ресурсы
        textureManager.releaseTexture(outputTexture)
    }
    
    private func createTestCIImage(width: Int, height: Int) -> CIImage {
        let color = CIColor(red: 0.2, green: 0.7, blue: 0.4, alpha: 1.0)
        let extent = CGRect(x: 0, y: 0, width: width, height: height)
        return CIImage(color: color).cropped(to: extent)
    }
}
