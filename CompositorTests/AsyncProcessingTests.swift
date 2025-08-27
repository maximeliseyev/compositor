//
//  AsyncProcessingTests.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 12.08.2025.
//

import XCTest
import CoreImage
import Metal
import MetalKit
@testable import Compositor

class AsyncProcessingTests: XCTestCase {
    
    var device: MTLDevice!
    var metalRenderer: MetalRenderer!
    var textureManager: TextureManager!
    var nodeGraph: NodeGraph!
    var processor: NodeGraphProcessor!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Инициализируем Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            XCTFail("Metal not supported on this device")
            return
        }
        
        self.device = device
        self.textureManager = TextureManager(device: device)
        self.metalRenderer = MetalRenderer(device: device, textureManager: textureManager)
        self.nodeGraph = NodeGraph()
        self.processor = NodeGraphProcessor(nodeGraph: nodeGraph)
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
    }
    
    // MARK: - Async Metal Processing Tests
    
    func testAsyncMetalProcessing() async throws {
        // Создаем тестовое изображение
        let testImage = createTestCIImage(width: 512, height: 512)
        
        // Тестируем асинхронную обработку через Metal
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let result = try await metalRenderer.processImage(
            testImage,
            withShader: "gaussian_blur_compute",
            parameters: ["radius": 5.0]
        )
        
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Проверяем, что обработка завершилась успешно
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.extent, testImage.extent)
        
        // Проверяем, что обработка не заняла слишком много времени
        XCTAssertLessThan(processingTime, 5.0, "Metal processing took too long")
        
        print("✅ Async Metal processing completed in \(processingTime)s")
    }
    
    func testConcurrentMetalOperations() async throws {
        // Создаем несколько тестовых изображений
        let testImages = (0..<3).map { _ in createTestCIImage(width: 256, height: 256) }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Запускаем обработку всех изображений одновременно
        let results = try await withThrowingTaskGroup(of: CIImage?.self) { group in
            for image in testImages {
                group.addTask {
                    return try await self.metalRenderer.processImage(
                        image,
                        withShader: "gaussian_blur_compute",
                        parameters: ["radius": 3.0]
                    )
                }
            }
            
            var outputResults: [CIImage?] = []
            for try await result in group {
                outputResults.append(result)
            }
            return outputResults
        }
        
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Проверяем результаты
        XCTAssertEqual(results.count, testImages.count)
        for result in results {
            XCTAssertNotNil(result)
        }
        
        // Проверяем, что параллельная обработка не заняла слишком много времени
        XCTAssertLessThan(processingTime, 10.0, "Concurrent processing took too long")
        
        print("✅ Concurrent Metal processing completed in \(processingTime)s")
    }
    
    func testAsyncTextureCopy() async throws {
        // Создаем тестовые текстуры
        let sourceTexture = createTestMTLTexture(width: 128, height: 128)
        let destinationTexture = createTestMTLTexture(width: 128, height: 128)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Тестируем асинхронное копирование текстур
        try await metalRenderer.copyTexture(from: sourceTexture, to: destinationTexture)
        
        let copyTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Проверяем, что копирование завершилось быстро
        XCTAssertLessThan(copyTime, 1.0, "Texture copy took too long")
        
        print("✅ Async texture copy completed in \(copyTime)s")
    }
    
    // MARK: - Async Node Graph Processing Tests
    
    func testAsyncNodeGraphProcessing() async throws {
        // Создаем простой граф нод
        let inputNode = InputNode(position: CGPoint(x: 100, y: 100))
        let blurNode = MetalBlurNode(type: .metalBlur, position: CGPoint(x: 300, y: 100))
        let viewNode = ViewNode(position: CGPoint(x: 500, y: 100))
        
        // Добавляем ноды в граф
        nodeGraph.addNode(inputNode)
        nodeGraph.addNode(blurNode)
        nodeGraph.addNode(viewNode)
        
        // Соединяем ноды
        nodeGraph.connectPorts(
            fromNode: inputNode,
            fromPort: inputNode.outputPorts[0],
            toNode: blurNode,
            toPort: blurNode.inputPorts[0]
        )
        
        nodeGraph.connectPorts(
            fromNode: blurNode,
            fromPort: blurNode.outputPorts[0],
            toNode: viewNode,
            toPort: viewNode.inputPorts[0]
        )
        
        // Загружаем тестовое изображение в InputNode
        let testImage = createTestCIImage(width: 256, height: 256)
        inputNode.setCurrentFrame(testImage)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Обрабатываем граф асинхронно
        await asyncProcessor.processGraphAsync()
        
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Проверяем, что обработка завершилась
        XCTAssertFalse(asyncProcessor.isProcessing)
        XCTAssertNil(asyncProcessor.errorMessage)
        
        // Проверяем, что обработка не заняла слишком много времени
        XCTAssertLessThan(processingTime, 10.0, "Node graph processing took too long")
        
        print("✅ Async node graph processing completed in \(processingTime)s")
    }
    
    func testAsyncNodeProcessingCancellation() async throws {
        // Создаем ноду с длительной обработкой
        let inputNode = InputNode(position: CGPoint(x: 100, y: 100))
        let testImage = createTestCIImage(width: 512, height: 512)
        inputNode.setCurrentFrame(testImage)
        
        nodeGraph.addNode(inputNode)
        
        // Запускаем обработку
        let processingTask = Task {
            await asyncProcessor.processGraphAsync()
        }
        
        // Ждем немного и отменяем
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
        processingTask.cancel()
        
        // Проверяем, что задача была отменена
        do {
            try await processingTask.value
            XCTFail("Task should have been cancelled")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        
        print("✅ Async processing cancellation test passed")
    }
    
    // MARK: - Performance Tests
    
    func testAsyncProcessingPerformance() async throws {
        // Создаем большой граф нод для тестирования производительности
        let nodes = (0..<5).map { i in
            let inputNode = InputNode(position: CGPoint(x: 100 + i * 200, y: 100))
            let testImage = createTestCIImage(width: 256, height: 256)
            inputNode.setCurrentFrame(testImage)
            return inputNode
        }
        
        for node in nodes {
            nodeGraph.addNode(node)
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Обрабатываем граф
        await asyncProcessor.processGraphAsync()
        
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Проверяем производительность
        XCTAssertLessThan(processingTime, 15.0, "Performance test failed - processing took too long")
        
        print("✅ Performance test completed in \(processingTime)s")
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

class AsyncProcessingIntegrationTests: XCTestCase {
    
    var device: MTLDevice!
    var nodeGraph: NodeGraph!
    var asyncProcessor: AsyncNodeGraphProcessor!
    var viewModel: AsyncNodeGraphViewModel!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            XCTFail("Metal not supported on this device")
            return
        }
        
        self.device = device
        self.nodeGraph = NodeGraph()
        self.asyncProcessor = AsyncNodeGraphProcessor(nodeGraph: nodeGraph)
        self.viewModel = AsyncNodeGraphViewModel(nodeGraph: nodeGraph)
    }
    
    func testAsyncProcessingWithUIUpdates() async throws {
        // Создаем ноды
        let inputNode = InputNode(position: CGPoint(x: 100, y: 100))
        let blurNode = MetalBlurNode(type: .metalBlur, position: CGPoint(x: 300, y: 100))
        
        // Добавляем через ViewModel
        await MainActor.run {
            viewModel.addNode(inputNode)
            viewModel.addNode(blurNode)
        }
        
        // Проверяем, что ноды добавлены
        await MainActor.run {
            XCTAssertEqual(viewModel.nodes.count, 2)
        }
        
        // Соединяем ноды
        await MainActor.run {
            viewModel.connectPorts(
                fromNode: inputNode,
                fromPort: inputNode.outputPorts[0],
                toNode: blurNode,
                toPort: blurNode.inputPorts[0]
            )
        }
        
        // Загружаем изображение
        let testImage = createTestCIImage(width: 256, height: 256)
        inputNode.setCurrentFrame(testImage)
        
        // Обрабатываем граф
        await asyncProcessor.processGraphAsync()
        
        // Проверяем состояние UI
        await MainActor.run {
            XCTAssertFalse(viewModel.isProcessing)
            XCTAssertNil(viewModel.errorMessage)
        }
        
        print("✅ Async processing with UI updates test passed")
    }
    
    private func createTestCIImage(width: Int, height: Int) -> CIImage {
        let color = CIColor(red: 0.2, green: 0.7, blue: 0.4, alpha: 1.0)
        let extent = CGRect(x: 0, y: 0, width: width, height: height)
        return CIImage(color: color).cropped(to: extent)
    }
}
