//
//  MetalNode.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 12.08.2025.
//

import SwiftUI
import CoreImage
import Metal

/// Базовый класс для нод, использующих Metal рендеринг
class MetalNode: BaseNode {
    
    // MARK: - Metal Properties
    private var metalRenderer: MetalRenderer?
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
        Task { @MainActor in
            let renderer = MetalRenderer()
            if renderer.isReady {
                self.metalRenderer = renderer
                self.isMetalAvailable = true
                print("✅ Metal renderer initialized for \(type.rawValue) node")
            } else {
                print("❌ Failed to initialize Metal renderer")
                self.isMetalAvailable = false
            }
        }
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
        guard let inputImage = inputs.first,
              let renderer = metalRenderer else {
            // Fallback to Core Image if Metal is not available
            return processWithCoreImage(inputs: inputs)
        }
        
        // Синхронная обработка через Metal
        let semaphore = DispatchSemaphore(value: 0)
        var result: CIImage?
        var processingError: Error?
        
        Task {
            do {
                result = try await processWithMetalShader(inputImage: inputImage!, renderer: renderer)
            } catch {
                processingError = error
                print("❌ Metal processing error: \(error)")
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = processingError {
            print("⚠️ Falling back to Core Image due to Metal error: \(error)")
            return processWithCoreImage(inputs: inputs)
        }
        
        return result
    }
    
    // MARK: - Metal Shader Processing
    /// Переопределяется в подклассах для специфичной обработки
    func processWithMetalShader(inputImage: CIImage, renderer: MetalRenderer) async throws -> CIImage? {
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
    
    override func processWithMetalShader(inputImage: CIImage, renderer: MetalRenderer) async throws -> CIImage? {
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
    
    override func processWithMetalShader(inputImage: CIImage, renderer: MetalRenderer) async throws -> CIImage? {
        let params = getMetalParameters()
        let blurType = parameters["blurType"] as? String ?? "gaussian"
        
        let shaderName = blurType == "gaussian" ? "gaussian_blur_compute" : "box_blur_compute"
        
        return try await renderer.processImage(
            inputImage,
            withShader: shaderName,
            parameters: params
        )
    }
    
    override func processWithCoreImage(inputs: [CIImage?]) -> CIImage? {
        guard let inputImage = inputs.first else { return nil }
        guard let radius = parameters["radius"] as? Float else { return inputImage }
        
        let filter = CIFilter(name: "CIGaussianBlur")
        filter?.setValue(inputImage, forKey: kCIInputImageKey)
        filter?.setValue(radius, forKey: kCIInputRadiusKey)
        
        return filter?.outputImage
    }
}
