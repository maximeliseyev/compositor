//
//  BrightnessNode.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 14.07.2025.
//

import SwiftUI
import CoreImage

class BrightnessNode: CoreImageNode {
    
    // MARK: - Brightness Parameters
    @Published var brightness: Float = 0.0 {
        didSet {
            parameters["brightness"] = brightness
            invalidateCache()
        }
    }
    
    @Published var contrast: Float = 1.0 {
        didSet {
            parameters["contrast"] = contrast
            invalidateCache()
        }
    }
    
    @Published var saturation: Float = 1.0 {
        didSet {
            parameters["saturation"] = saturation
            invalidateCache()
        }
    }
    
    // MARK: - Initialization
    override init(type: NodeType = .brightness, position: CGPoint) {
        super.init(type: type, position: position)
        setupBrightnessNode()
    }
    
    private func setupBrightnessNode() {
        // Initialize parameters
        parameters["brightness"] = brightness
        parameters["contrast"] = contrast
        parameters["saturation"] = saturation
        
        print("💡 BrightnessNode initialized with Core Image")
    }
    
    // MARK: - Core Image Processing
    
    override func processWithCoreImage(inputs: [CIImage?]) -> CIImage? {
        guard let inputImage = inputs.first else { return nil }
        
        // Используем CIColorControls для настройки яркости, контраста и насыщенности
        guard let filter = getOrCreateFilter(name: "CIColorControls") else {
            print("⚠️ Failed to create CIColorControls filter")
            return inputImage
        }
        
        // Настраиваем фильтр
        filter.setValue(inputImage, forKey: kCIInputImageKey)
        filter.setValue(brightness, forKey: kCIInputBrightnessKey)
        filter.setValue(contrast, forKey: kCIInputContrastKey)
        filter.setValue(saturation, forKey: kCIInputSaturationKey)
        
        // Получаем результат
        guard let outputImage = filter.outputImage else {
            print("⚠️ CIColorControls filter output is nil")
            return inputImage
        }
        
        return outputImage
    }
    
    // MARK: - Parameter Management
    
    /// Устанавливает яркость
    func setBrightness(_ value: Float) {
        brightness = value
    }
    
    /// Устанавливает контраст
    func setContrast(_ value: Float) {
        contrast = value
    }
    
    /// Устанавливает насыщенность
    func setSaturation(_ value: Float) {
        saturation = value
    }
    
    /// Сбрасывает параметры к значениям по умолчанию
    func resetToDefaults() {
        brightness = 0.0
        contrast = 1.0
        saturation = 1.0
    }
    
    // MARK: - Performance Info Override
    
    override func getPerformanceInfo() -> String {
        let baseInfo = super.getPerformanceInfo()
        return """
        \(baseInfo)
        Brightness: \(brightness)
        Contrast: \(contrast)
        Saturation: \(saturation)
        """
    }
}
