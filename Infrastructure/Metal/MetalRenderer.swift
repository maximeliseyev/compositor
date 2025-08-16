//
//  MetalRenderer.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 12.08.2025.
//


import Foundation
@preconcurrency import Metal
@preconcurrency import MetalKit
import SwiftUI
@preconcurrency import CoreImage

class MetalRenderer: ObservableObject, @unchecked Sendable {
    
    // MARK: - Metal Properties
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    
    // MARK: - Pipeline Cache
    private var renderPipelineCache: [String: MTLRenderPipelineState] = [:]
    private var computePipelineCache: [String: MTLComputePipelineState] = [:]
    
    // MARK: - Managers
    let textureManager: TextureManager
    
    // MARK: - Published Properties
    @Published var isReady = false
    @Published var errorMessage: String?
    
    init() {
        // Проверяем доступность Metal
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal not supported on this device")
        }
        
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Could not create Metal command queue")
        }
        
        // Пытаемся загрузить шейдеры
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Could not load Metal shaders library")
        }
        
        self.device = device
        self.commandQueue = commandQueue
        self.library = library
        self.textureManager = TextureManager(device: device)
        
        self.isReady = true
        
        print("✅ Metal initialized successfully")
        print("📱 Device: \(device.name)")
        print("🔧 Max threads per group: \(device.maxThreadsPerThreadgroup)")
    }
    
    // MARK: - CIImage Integration
    
    // MARK: - Shared CIContext for performance
    private lazy var sharedCIContext: CIContext = {
        CIContext(mtlDevice: device, options: [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            .cacheIntermediates: false // Prevent memory accumulation
        ])
    }()
    
    /// Конвертирует CIImage в MTLTexture
    func textureFromCIImage(_ ciImage: CIImage) async throws -> MTLTexture? {
        // Захватываем необходимые значения на MainActor до перехода на фон
        let extent = ciImage.extent
        guard let texture = self.textureManager.acquireTexture(
            width: Int(extent.width),
            height: Int(extent.height),
            pixelFormat: MTLPixelFormat.rgba8Unorm
        ) else {
            throw MetalError.cannotCreateTexture
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: MetalError.rendererDeallocated)
                    return
                }
                
                self.sharedCIContext.render(
                    ciImage,
                    to: texture,
                    commandBuffer: nil,
                    bounds: extent,
                    colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
                )
                continuation.resume(returning: texture)
            }
        }
    }
    
    /// Конвертирует MTLTexture в CIImage
    func ciImageFromTexture(_ texture: MTLTexture) -> CIImage? {
        let ciImage = CIImage(mtlTexture: texture, options: nil)
        return ciImage
    }
    
    // MARK: - Node Processing Interface
    
    /// Обрабатывает изображение через Metal шейдер
    func processImage(_ inputImage: CIImage, withShader shaderName: String, parameters: [String: Any] = [:]) async throws -> CIImage? {
        guard let inputTexture = try await textureFromCIImage(inputImage) else {
            throw MetalError.cannotCreateTexture
        }
        
        let outputTexture = textureManager.acquireTexture(
            width: inputTexture.width,
            height: inputTexture.height,
            pixelFormat: inputTexture.pixelFormat
        )
        
        guard let outputTexture = outputTexture else {
            throw MetalError.cannotCreateTexture
        }
        
        // Применяем шейдер
        try await applyComputeShader(
            shaderName: shaderName,
            inputTexture: inputTexture,
            outputTexture: outputTexture,
            parameters: parameters
        )
        
        // Конвертируем обратно в CIImage
        let result = ciImageFromTexture(outputTexture)
        
        // Освобождаем текстуры
        textureManager.releaseTexture(inputTexture)
        textureManager.releaseTexture(outputTexture)
        
        return result
    }
    
    /// Применяет compute шейдер к текстурам
    private func applyComputeShader(
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
        
        // Устанавливаем параметры если есть
        if !parameters.isEmpty {
            let (buffer, _) = try createParameterBuffer(parameters: parameters)
            computeEncoder.setBuffer(buffer, offset: 0, index: 0)
            // Optionally: we can validate length against expected struct sizes per shader
        }
        
        // Вычисляем размеры thread groups
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (outputTexture.width + threadGroupSize.width - 1) / threadGroupSize.width,
            height: (outputTexture.height + threadGroupSize.height - 1) / threadGroupSize.height,
            depth: 1
        )
        
        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    /// Создает буфер параметров для шейдера
    private func createParameterBuffer(parameters: [String: Any]) throws -> (MTLBuffer, Int) {
        // Поддержим разные наборы параметров. Для Blur ожидаем BlurParams (5 полей = 32 байта выравнивания).
        if parameters.keys.contains("radius") && parameters.keys.contains("textureWidth") {
            // Собираем BlurParams вручную
            struct BlurParamsCPU {
                var radius: Float
                var direction: SIMD2<Float>
                var textureSize: SIMD2<Float>
                var samples: Int32
            }
            let rp: Float = (parameters["radius"] as? Float) ?? Float((parameters["radius"] as? Double) ?? 0)
            let dir = SIMD2<Float>(
                Float((parameters["dirX"] as? Float) ?? 1.0),
                Float((parameters["dirY"] as? Float) ?? 0.0)
            )
            let texSize = SIMD2<Float>(
                Float(parameters["textureWidth"] as? Int ?? 0),
                Float(parameters["textureHeight"] as? Int ?? 0)
            )
            let smp: Int32 = Int32(parameters["samples"] as? Int ?? 0)
            var cpu = BlurParamsCPU(radius: rp, direction: dir, textureSize: texSize, samples: smp)
            let length = MemoryLayout<BlurParamsCPU>.stride
            guard let buffer = device.makeBuffer(bytes: &cpu, length: length, options: .storageModeShared) else {
                throw MetalError.cannotCreateBuffer
            }
            return (buffer, length)
        }
        
        // Generic float packing fallback
        var floatParams: [Float] = []
        for (_, value) in parameters {
            if let floatValue = value as? Float { floatParams.append(floatValue) }
            else if let intValue = value as? Int { floatParams.append(Float(intValue)) }
            else if let doubleValue = value as? Double { floatParams.append(Float(doubleValue)) }
        }
        let length = floatParams.count * MemoryLayout<Float>.size
        guard let buffer = device.makeBuffer(bytes: floatParams, length: length, options: .storageModeShared) else {
            throw MetalError.cannotCreateBuffer
        }
        return (buffer, length)
    }

    // MARK: - Pipeline State Creation
    func getRenderPipelineState(
        vertexFunction: String = "vertex_main",
        fragmentFunction: String,
        pixelFormat: MTLPixelFormat = .rgba8Unorm
    ) throws -> MTLRenderPipelineState {
        
        let key = "\(vertexFunction)_\(fragmentFunction)_\(pixelFormat.rawValue)"
        
        if let cached = renderPipelineCache[key] {
            return cached
        }
        
        guard let vertexFunc = library.makeFunction(name: vertexFunction) else {
            throw MetalError.functionNotFound(vertexFunction)
        }
        
        guard let fragmentFunc = library.makeFunction(name: fragmentFunction) else {
            throw MetalError.functionNotFound(fragmentFunction)
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunc
        descriptor.fragmentFunction = fragmentFunc
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        
        let pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        renderPipelineCache[key] = pipelineState
        
        print("🔨 Created render pipeline: \(key)")
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
    
    // MARK: - Texture Loading
    func loadTexture(from imagePath: String) async throws -> MTLTexture? {
        // Избегаем обращения к свойствам @MainActor внутри фоновой очереди
        let device = self.device
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    guard let image = NSImage(contentsOfFile: imagePath) else {
                        throw MetalError.cannotLoadImage(imagePath)
                    }

                    guard let cgImage = image.cgImage(
                        forProposedRect: nil,
                        context: nil,
                        hints: nil
                    ) else {
                        throw MetalError.cannotCreateCGImage
                    }

                    let textureLoader = MTKTextureLoader(device: device)
                    let texture = try textureLoader.newTexture(cgImage: cgImage)

                    print("📷 Loaded texture: \(texture.width)x\(texture.height)")
                    continuation.resume(returning: texture)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Basic Rendering Operations
    func createBlankTexture(width: Int, height: Int, pixelFormat: MTLPixelFormat = .rgba8Unorm) -> MTLTexture? {
        return textureManager.acquireTexture(
            width: width,
            height: height,
            pixelFormat: pixelFormat
        )
    }
    
    func copyTexture(from source: MTLTexture, to destination: MTLTexture) throws {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw MetalError.cannotCreateCommandBuffer
        }
        
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            throw MetalError.cannotCreateEncoder
        }
        
        blitEncoder.copy(
            from: source,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: source.width, height: source.height, depth: 1),
            to: destination,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        
        blitEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    // MARK: - Debug Helpers
    func getDeviceInfo() -> String {
        return """
        📱 Device: \(device.name)
        🔧 Max threads per group: \(device.maxThreadsPerThreadgroup)
        💾 Recommended working set size: \(device.recommendedMaxWorkingSetSize / 1024 / 1024) MB
        ⚡ Low power: \(device.isLowPower)
        """
    }
}

// MARK: - Error Definitions
enum MetalError: LocalizedError {
    case functionNotFound(String)
    case cannotLoadImage(String)
    case cannotCreateCGImage
    case cannotCreateCommandBuffer
    case cannotCreateEncoder
    case cannotCreateTexture
    case cannotCreateBuffer
    case rendererDeallocated
    
    var errorDescription: String? {
        switch self {
        case .functionNotFound(let name):
            return "Metal function '\(name)' not found in shader library"
        case .cannotLoadImage(let path):
            return "Cannot load image from: \(path)"
        case .cannotCreateCGImage:
            return "Cannot create CGImage from NSImage"
        case .cannotCreateCommandBuffer:
            return "Cannot create Metal command buffer"
        case .cannotCreateEncoder:
            return "Cannot create Metal encoder"
        case .cannotCreateTexture:
            return "Cannot create Metal texture"
        case .cannotCreateBuffer:
            return "Cannot create Metal buffer"
        case .rendererDeallocated:
            return "MetalRenderer was deallocated"
        }
    }
}
