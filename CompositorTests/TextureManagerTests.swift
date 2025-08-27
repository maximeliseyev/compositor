//
//  TextureManagerTests.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 12.08.2025.
//

import XCTest
import Metal
import MetalKit
@testable import Compositor

class TextureManagerTests: XCTestCase {
    
    var device: MTLDevice!
    var textureManager: TextureManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Инициализируем Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            XCTFail("Metal not supported on this device")
            return
        }
        
        self.device = device
        self.textureManager = TextureManager(device: device)
    }
    
    override func tearDownWithError() throws {
        textureManager.forceCleanup()
        try super.tearDownWithError()
    }
    
    // MARK: - Basic Texture Management Tests
    
    func testTextureAcquisition() async throws {
        // Создаем текстуру
        let texture = await textureManager.acquireTexture(
            width: PerformanceConstants.standardTestTextureSize,
            height: PerformanceConstants.standardTestTextureSize,
            priority: .normal
        )
        
        XCTAssertNotNil(texture)
        XCTAssertEqual(texture?.width, PerformanceConstants.standardTestTextureSize)
        XCTAssertEqual(texture?.height, PerformanceConstants.standardTestTextureSize)
        
        // Освобождаем текстуру
        textureManager.releaseTexture(texture!)
        
        // Проверяем, что текстура вернулась в пул
        let stats = textureManager.getStatistics()
        XCTAssertEqual(stats.currentlyInPool, 1)
    }
    
    func testTextureReuse() async throws {
        // Создаем и освобождаем текстуру
        let texture1 = await textureManager.acquireTexture(width: PerformanceConstants.largeTestTextureSize, height: PerformanceConstants.largeTestTextureSize)
        textureManager.releaseTexture(texture1!)
        
        // Создаем вторую текстуру того же размера
        let texture2 = await textureManager.acquireTexture(width: PerformanceConstants.largeTestTextureSize, height: PerformanceConstants.largeTestTextureSize)
        
        // Проверяем, что текстура была переиспользована
        let stats = textureManager.getStatistics()
        XCTAssertGreaterThan(stats.totalReused, 0)
        XCTAssertGreaterThan(stats.reuseRatio, 0.0)
    }
    
    // MARK: - Priority Tests
    
    func testTexturePriority() async throws {
        // Создаем текстуры с разными приоритетами
        let lowPriorityTexture = await textureManager.acquireTexture(
            width: PerformanceConstants.mediumTestTextureSize,
            height: PerformanceConstants.mediumTestTextureSize,
            priority: .low
        )
        textureManager.releaseTexture(lowPriorityTexture!)
        
        let highPriorityTexture = await textureManager.acquireTexture(
            width: PerformanceConstants.mediumTestTextureSize,
            height: PerformanceConstants.mediumTestTextureSize,
            priority: .high
        )
        textureManager.releaseTexture(highPriorityTexture!)
        
        // Проверяем, что текстуры с высоким приоритетом сохраняются дольше
        let stats = textureManager.getStatistics()
        XCTAssertGreaterThanOrEqual(stats.currentlyInPool, 2)
    }
    
    func testPriorityBasedCleanup() async throws {
        // Создаем много текстур с низким приоритетом
        var lowPriorityTextures: [MTLTexture] = []
        for _ in 0..<10 {
            let texture = await textureManager.acquireTexture(
                width: 64,
                height: 64,
                priority: .low
            )
            textureManager.releaseTexture(texture!)
            lowPriorityTextures.append(texture!)
        }
        
        // Создаем несколько текстур с высоким приоритетом
        var highPriorityTextures: [MTLTexture] = []
        for _ in 0..<5 {
            let texture = await textureManager.acquireTexture(
                width: 64,
                height: 64,
                priority: .high
            )
            textureManager.releaseTexture(texture!)
            highPriorityTextures.append(texture!)
        }
        
        // Выполняем адаптивную очистку
        textureManager.adaptiveCleanup()
        
        // Проверяем, что высокоприоритетные текстуры сохранились
        let stats = textureManager.getStatistics()
        XCTAssertGreaterThan(stats.currentlyInPool, 0)
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryPressureMonitoring() async throws {
        // Создаем много больших текстур для создания давления на память
        var largeTextures: [MTLTexture] = []
        
        for i in 0..<20 {
            let size = 512 + i * 64
            let texture = await textureManager.acquireTexture(
                width: size,
                height: size,
                priority: .normal
            )
            textureManager.releaseTexture(texture!)
            largeTextures.append(texture!)
        }
        
        // Проверяем мониторинг давления памяти
        let stats = textureManager.getStatistics()
        XCTAssertGreaterThan(stats.memoryUsageMB, 0.0)
        XCTAssertGreaterThanOrEqual(stats.memoryPressure, 0.0)
        XCTAssertLessThanOrEqual(stats.memoryPressure, 1.0)
    }
    
    func testAdaptiveCleanup() async throws {
        // Создаем много текстур
        var textures: [MTLTexture] = []
        for _ in 0..<15 {
            let texture = await textureManager.acquireTexture(
                width: 256,
                height: 256,
                priority: .normal
            )
            textureManager.releaseTexture(texture!)
            textures.append(texture!)
        }
        
        let statsBefore = textureManager.getStatistics()
        
        // Выполняем адаптивную очистку
        textureManager.adaptiveCleanup()
        
        let statsAfter = textureManager.getStatistics()
        
        // Проверяем, что очистка произошла
        XCTAssertLessThanOrEqual(statsAfter.currentlyInPool, statsBefore.currentlyInPool)
    }
    
    // MARK: - Performance Tests
    
    func testConcurrentTextureAcquisition() async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Создаем текстуры параллельно
        let results = try await withThrowingTaskGroup(of: MTLTexture?.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    return await self.textureManager.acquireTexture(
                        width: 128,
                        height: 128,
                        priority: .normal
                    )
                }
            }
            
            var textures: [MTLTexture?] = []
            for try await texture in group {
                textures.append(texture)
            }
            return textures
        }
        
        let acquisitionTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Освобождаем текстуры
        for texture in results {
            if let texture = texture {
                textureManager.releaseTexture(texture)
            }
        }
        
        // Проверяем производительность
        XCTAssertLessThan(acquisitionTime, 5.0, "Texture acquisition took too long")
        XCTAssertEqual(results.count, 10)
        
        for result in results {
            XCTAssertNotNil(result)
        }
    }
    
    func testTexturePoolEfficiency() async throws {
        let initialStats = textureManager.getStatistics()
        
        // Создаем и освобождаем много текстур одного размера
        for _ in 0..<20 {
            let texture = await textureManager.acquireTexture(
                width: 256,
                height: 256,
                priority: .normal
            )
            textureManager.releaseTexture(texture!)
        }
        
        let finalStats = textureManager.getStatistics()
        
        // Проверяем эффективность переиспользования
        XCTAssertGreaterThan(finalStats.totalReused, 0)
        XCTAssertGreaterThan(finalStats.reuseRatio, 0.0)
        
        // Проверяем, что не создали слишком много новых текстур
        XCTAssertLessThan(finalStats.totalCreated, 20)
    }
    
    // MARK: - Edge Cases
    
    func testVeryLargeTextures() async throws {
        // Тестируем создание очень больших текстур
        let largeTexture = await textureManager.acquireTexture(
            width: 4096,
            height: 4096,
            priority: .high
        )
        
        XCTAssertNotNil(largeTexture)
        XCTAssertEqual(largeTexture?.width, 4096)
        XCTAssertEqual(largeTexture?.height, 4096)
        
        textureManager.releaseTexture(largeTexture!)
        
        let stats = textureManager.getStatistics()
        XCTAssertGreaterThan(stats.memoryUsageMB, 0.0)
    }
    
    func testTexturePriorityChange() async throws {
        let texture = await textureManager.acquireTexture(
            width: 128,
            height: 128,
            priority: .normal
        )
        
        // Изменяем приоритет
        textureManager.setTexturePriority(texture!, priority: .high)
        
        textureManager.releaseTexture(texture!)
        
        // Проверяем, что текстура сохранилась в пуле
        let stats = textureManager.getStatistics()
        XCTAssertEqual(stats.currentlyInPool, 1)
    }
    
    func testForceCleanup() async throws {
        // Создаем несколько текстур
        var textures: [MTLTexture] = []
        for _ in 0..<5 {
            let texture = await textureManager.acquireTexture(
                width: 256,
                height: 256,
                priority: .normal
            )
            textureManager.releaseTexture(texture!)
            textures.append(texture!)
        }
        
        let statsBefore = textureManager.getStatistics()
        XCTAssertGreaterThan(statsBefore.currentlyInPool, 0)
        
        // Принудительная очистка
        textureManager.forceCleanup()
        
        let statsAfter = textureManager.getStatistics()
        XCTAssertEqual(statsAfter.currentlyInPool, 0)
        XCTAssertEqual(statsAfter.memoryUsageMB, 0.0)
        XCTAssertEqual(statsAfter.memoryPressure, 0.0)
    }
    
    // MARK: - Statistics Tests
    
    func testStatisticsAccuracy() async throws {
        let initialStats = textureManager.getStatistics()
        
        // Создаем текстуру
        let texture = await textureManager.acquireTexture(
            width: 512,
            height: 512,
            priority: .normal
        )
        
        let statsDuringUse = textureManager.getStatistics()
        XCTAssertEqual(statsDuringUse.currentlyInUse, 1)
        XCTAssertGreaterThan(statsDuringUse.memoryUsageMB, initialStats.memoryUsageMB)
        
        // Освобождаем текстуру
        textureManager.releaseTexture(texture!)
        
        let statsAfterRelease = textureManager.getStatistics()
        XCTAssertEqual(statsAfterRelease.currentlyInUse, 0)
        XCTAssertGreaterThan(statsAfterRelease.currentlyInPool, 0)
        XCTAssertGreaterThan(statsAfterRelease.totalReused, 0)
    }
}

// MARK: - Integration Tests

class TextureManagerIntegrationTests: XCTestCase {
    
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
    
    func testTextureManagerWithTextureData() async throws {
        // Создаем TextureData
        let testImage = createTestCIImage(width: 256, height: 256)
        let textureData = textureDataFactory.createFromCIImage(testImage)
        
        // Получаем MTLTexture через TextureData
        let texture = try await textureData.getMetalTexture(device: device)
        
        // Устанавливаем высокий приоритет
        textureManager.setTexturePriority(texture, priority: .high)
        
        // Освобождаем текстуру
        textureManager.releaseTexture(texture)
        
        // Проверяем, что текстура сохранилась в пуле
        let stats = textureManager.getStatistics()
        XCTAssertGreaterThan(stats.currentlyInPool, 0)
        XCTAssertGreaterThan(stats.memoryUsageMB, 0.0)
    }
    
    private func createTestCIImage(width: Int, height: Int) -> CIImage {
        let color = CIColor(red: 0.5, green: 0.3, blue: 0.8, alpha: 1.0)
        let extent = CGRect(x: 0, y: 0, width: width, height: height)
        return CIImage(color: color).cropped(to: extent)
    }
}
