//
//  MetalNode.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 12.08.2025.
//

import SwiftUI
import CoreImage
import Metal

// Forward declaration for MetalRenderer
protocol MetalRendererProtocol {
    var isReady: Bool { get }
    func processImage(_ image: CIImage, withShader shaderName: String, parameters: [String: Any]) async throws -> CIImage?
}



/// Базовый класс для нод, использующих Metal рендеринг
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
    
    // MARK: - Initialization
    override init(type: NodeType, position: CGPoint) {
        super.init(type: type, position: position)
        setupMetalRenderer()
    }
    
    // MARK: - Metal Setup
    private func setupMetalRenderer() {
        // Временно отключаем Metal рендерер до интеграции
        self.isMetalAvailable = false
        print("ℹ️ Metal renderer temporarily disabled")
    }
    
    // MARK: - Processing Override
    override func process(inputs: [CIImage?]) -> CIImage? {
        guard inputs.first != nil else {
            return nil
        }
        
        switch processingMode {
        case .coreImage:
            return processWithCoreImage(inputs: inputs)
        case .metal:
            return processWithMetal(inputs: inputs)
        case .auto:
            return isMetalAvailable ? processWithMetal(inputs: inputs) : processWithCoreImage(inputs: inputs)
        }
    }
    
    // MARK: - Core Image Processing
    func processWithCoreImage(inputs: [CIImage?]) -> CIImage? {
        // Базовая реализация - просто возвращает входное изображение
        // Переопределяется в подклассах
        return inputs.first ?? nil
    }
    
    // MARK: - Metal Processing
    private func processWithMetal(inputs: [CIImage?]) -> CIImage? {
        // Unwrap nested optionals safely
        guard let first = inputs.first else {
            print("⚠️ MetalNode received empty inputs")
            return nil
        }
        guard let inputImage = first else {
            print("⚠️ MetalNode received nil input image")
            return nil
        }
        guard let renderer = metalRenderer else {
            // Fallback to Core Image if Metal is not available
            print("ℹ️ Metal renderer not ready, using Core Image path")
            return processWithCoreImage(inputs: inputs)
        }
        
        // Синхронная обёртка вокруг async без блокировки MainActor
        var output: CIImage?
        var thrownError: Error?
        let group = DispatchGroup()
        group.enter()
        Task.detached(priority: .userInitiated) { [self] in
            do {
                output = try await self.processWithMetalShader(inputImage: inputImage, renderer: renderer)
            } catch {
                thrownError = error
            }
            group.leave()
        }
        group.wait()
        
        if let error = thrownError {
            print("⚠️ Falling back to Core Image due to Metal error: \(error)")
            return processWithCoreImage(inputs: inputs)
        }
        return output
    }
    
    // MARK: - Metal Shader Processing
    /// Переопределяется в подклассах для специфичной обработки
    func processWithMetalShader(inputImage: CIImage, renderer: MetalRendererProtocol) async throws -> CIImage? {
        // Базовая реализация - просто возвращает входное изображение
        // Переопределяется в подклассах для специфичной обработки
        return inputImage
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
            return "Metal: Available"
        } else {
            return "Metal: Not available (using Core Image)"
        }
    }
}

// MARK: - Modern Unified Blur Node

/// Modern blur node with intelligent Metal/MPS processing
class BlurNode: MetalNode {
    
    @Published var radius: Float = 5.0 {
        didSet { 
            parameters["radius"] = radius
        }
    }
    
    override init(type: NodeType = .metalBlur, position: CGPoint) {
        super.init(type: type, position: position)
        setupBlurNode()
    }
    
    private func setupBlurNode() {
        // Initialize parameters (ports are created automatically from metadata)
        parameters["radius"] = radius
        parameters["blurType"] = "gaussian"
        
        print("🌫️ BlurNode initialized")
    }
    
    override func processWithMetalShader(inputImage: CIImage, renderer: MetalRendererProtocol) async throws -> CIImage? {
        let params = getMetalParameters()
        let shaderName = "gaussian_blur_compute"
        
        // Add required parameters for BlurParams
        var fullParams = params
        fullParams["textureWidth"] = Float(inputImage.extent.width)
        fullParams["textureHeight"] = Float(inputImage.extent.height)
        fullParams["dirX"] = 1.0
        fullParams["dirY"] = 0.0
        fullParams["samples"] = 0
        
        do {
            return try await renderer.processImage(
                inputImage,
                withShader: shaderName,
                parameters: fullParams
            )
        } catch {
            print("❗ Metal blur failed, using Core Image: \(error)")
            return processWithCoreImage(inputs: [inputImage])
        }
    }
    
    override func processWithCoreImage(inputs: [CIImage?]) -> CIImage? {
        guard let inputImage = inputs.first as? CIImage else { return nil }
        
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return inputImage }
        filter.setValue(inputImage, forKey: kCIInputImageKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        
        return filter.outputImage?.cropped(to: inputImage.extent)
    }
}

// MARK: - Metal Node Types

/// Нода для цветокоррекции через Metal
class MetalCorrectorNode: MetalNode {
    
    override init(type: NodeType, position: CGPoint) {
        super.init(type: type, position: position)
        
        // Инициализируем параметры цветокоррекции
        parameters["exposure"] = 0.0
        parameters["contrast"] = 1.0
        parameters["saturation"] = 1.0
        parameters["brightness"] = 0.0
        parameters["temperature"] = 0.0
    }
    
    override func processWithMetalShader(inputImage: CIImage, renderer: MetalRendererProtocol) async throws -> CIImage? {
        let params = getMetalParameters()
        return try await renderer.processImage(
            inputImage,
            withShader: "color_correction_fragment",
            parameters: params
        )
    }
    
    override func processWithCoreImage(inputs: [CIImage?]) -> CIImage? {
        guard let inputImage = inputs.first else { return nil }
        
        var result = inputImage
        
        // Применяем цветокоррекцию через Core Image
        if let exposure = parameters["exposure"] as? Float, exposure != 0.0 {
            let filter = CIFilter(name: "CIExposureAdjust")
            filter?.setValue(result, forKey: kCIInputImageKey)
            filter?.setValue(exposure, forKey: kCIInputEVKey)
            if let output = filter?.outputImage {
                result = output
            }
        }
        
        if let contrast = parameters["contrast"] as? Float, contrast != 1.0 {
            let filter = CIFilter(name: "CIColorControls")
            filter?.setValue(result, forKey: kCIInputImageKey)
            filter?.setValue(contrast, forKey: kCIInputSaturationKey)
            if let output = filter?.outputImage {
                result = output
            }
        }
        
        return result
    }
}

/// Нода для размытия через Metal
class MetalBlurNode: MetalNode {
    
    override init(type: NodeType, position: CGPoint) {
        super.init(type: type, position: position)
        
        // Инициализируем параметры размытия
        parameters["radius"] = 5.0
        parameters["blurType"] = "gaussian" // "gaussian" или "box"
    }
    
    override func processWithMetalShader(inputImage: CIImage, renderer: MetalRendererProtocol) async throws -> CIImage? {
        let params = getMetalParameters()
        let blurType = parameters["blurType"] as? String ?? "gaussian"
        let shaderName = blurType == "gaussian" ? "gaussian_blur_compute" : "box_blur_compute"
        
        // Добавим обязательные параметры для BlurParams
        var fullParams = params
        fullParams["textureWidth"] = Float(inputImage.extent.width)
        fullParams["textureHeight"] = Float(inputImage.extent.height)
        // Направление размытия по умолчанию — горизонталь
        fullParams["dirX"] = 1.0
        fullParams["dirY"] = 0.0
        fullParams["samples"] = 0
        
        do {
            return try await renderer.processImage(
                inputImage,
                withShader: shaderName,
                parameters: fullParams
            )
        } catch {
            print("❗ Metal blur failed, falling back to Core Image: \(error)")
            return processWithCoreImage(inputs: [inputImage])
        }
    }
    
    override func processWithCoreImage(inputs: [CIImage?]) -> CIImage? {
        guard let inputImage = inputs.first, let image = inputImage else { return nil }
        guard let radius = parameters["radius"] as? Float else { return image }
        
        let filter = CIFilter(name: "CIGaussianBlur")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(radius, forKey: kCIInputRadiusKey)
        
        return filter?.outputImage
    }
}
