//
//  ColorWheelsNode.swift
//  Compositor
//
//  Professional Color Correction Node
//
//  Created by Architecture Refactor on 12.08.2025.
//

import Foundation
import SwiftUI
import CoreImage
import simd
import Combine

// MARK: - Color Wheels Node

/// Профессиональная нода цветокоррекции с колесами теней/средних тонов/светов
class ColorWheelsNode: BaseNode {
    
    // MARK: - Color Correction Parameters
    
    /// Коррекция теней
    @Published var shadows = ColorWheel()
    
    /// Коррекция средних тонов  
    @Published var midtones = ColorWheel()
    
    /// Коррекция светов
    @Published var highlights = ColorWheel()
    
    /// Общий контраст
    @Published var contrast: Float = 1.0 {
        didSet { invalidateCache() }
    }
    
    /// Общая насыщенность
    @Published var saturation: Float = 1.0 {
        didSet { invalidateCache() }
    }
    
    /// Общая яркость (exposure)
    @Published var exposure: Float = 0.0 {
        didSet { invalidateCache() }
    }
    
    /// Сила эффекта (0.0 - 1.0)
    @Published var strength: Float = 1.0 {
        didSet { invalidateCache() }
    }
    
    /// Включить/выключить эффект
    @Published var isEnabled: Bool = true {
        didSet { invalidateCache() }
    }
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    override init(type: NodeType, position: CGPoint) {
        super.init(type: type, position: position)
        setupParameters()
        setupBindings()
    }
    
    convenience init(position: CGPoint) {
        self.init(type: .colorWheels, position: position)
    }
    
    // MARK: - Setup
    
    private func setupParameters() {
        updateParametersFromControls()
    }
    
    private func setupBindings() {
        // Подписываемся на изменения колес
        shadows.objectWillChange.sink { [weak self] _ in
            self?.invalidateCache()
            self?.updateParametersFromControls()
        }.store(in: &cancellables)
        
        midtones.objectWillChange.sink { [weak self] _ in
            self?.invalidateCache()
            self?.updateParametersFromControls()
        }.store(in: &cancellables)
        
        highlights.objectWillChange.sink { [weak self] _ in
            self?.invalidateCache()
            self?.updateParametersFromControls()
        }.store(in: &cancellables)
    }
    
    // MARK: - Processing
    
    override func process(inputs: [CIImage?]) -> CIImage? {
        guard let inputImage = inputs.first ?? nil,
              isEnabled else {
            return inputs.first ?? nil
        }
        
        // Применяем цветокоррекцию через Core Image
        return applyColorWheelsCorrection(to: inputImage)
    }
    
    private func applyColorWheelsCorrection(to image: CIImage) -> CIImage? {
        // Простая реализация через стандартные фильтры Core Image
        var result = image
        
        // Применяем exposure
        if exposure != 0.0 {
            let exposureFilter = CIFilter(name: "CIExposureAdjust")
            exposureFilter?.setValue(result, forKey: kCIInputImageKey)
            exposureFilter?.setValue(exposure, forKey: kCIInputEVKey)
            result = exposureFilter?.outputImage ?? result
        }
        
        // Применяем контраст
        if contrast != 1.0 {
            let contrastFilter = CIFilter(name: "CIColorControls")
            contrastFilter?.setValue(result, forKey: kCIInputImageKey)
            contrastFilter?.setValue(contrast, forKey: kCIInputContrastKey)
            result = contrastFilter?.outputImage ?? result
        }
        
        // Применяем насыщенность
        if saturation != 1.0 {
            let saturationFilter = CIFilter(name: "CIColorControls")
            saturationFilter?.setValue(result, forKey: kCIInputImageKey)
            saturationFilter?.setValue(saturation, forKey: kCIInputSaturationKey)
            result = saturationFilter?.outputImage ?? result
        }
        
        return result
    }
    
    // MARK: - Parameter Management
    
    private func updateParametersFromControls() {
        parameters = [
            "contrast": contrast,
            "saturation": saturation,
            "exposure": exposure,
            "strength": strength,
            "enabled": isEnabled
        ]
    }
    
    override func setParameter(key: String, value: Any) {
        super.setParameter(key: key, value: value)
        
        switch key {
        case "contrast":
            if let floatValue = value as? Float {
                contrast = floatValue
            }
        case "saturation":
            if let floatValue = value as? Float {
                saturation = floatValue
            }
        case "exposure":
            if let floatValue = value as? Float {
                exposure = floatValue
            }
        case "strength":
            if let floatValue = value as? Float {
                strength = floatValue
            }
        case "enabled":
            if let boolValue = value as? Bool {
                isEnabled = boolValue
            }
        default:
            break
        }
    }
    
    // MARK: - Presets
    
    /// Применяет пресет цветокоррекции
    func applyPreset(_ preset: ColorCorrectionPreset) {
        switch preset {
        case .neutral:
            resetToDefaults()
        case .warmTone:
            applyWarmTonePreset()
        case .coolTone:
            applyCoolTonePreset()
        case .vintage:
            applyVintagePreset()
        case .dramatic:
            applyDramaticPreset()
        }
    }
    
    private func resetToDefaults() {
        shadows = ColorWheel()
        midtones = ColorWheel()
        highlights = ColorWheel()
        contrast = 1.0
        saturation = 1.0
        exposure = 0.0
        strength = 1.0
    }
    
    private func applyWarmTonePreset() {
        contrast = 1.1
        saturation = 1.05
        exposure = 0.1
    }
    
    private func applyCoolTonePreset() {
        contrast = 1.05
        saturation = 0.95
        exposure = -0.05
    }
    
    private func applyVintagePreset() {
        contrast = 0.9
        saturation = 0.8
        exposure = 0.1
    }
    
    private func applyDramaticPreset() {
        contrast = 1.3
        saturation = 1.2
        exposure = 0.2
    }
}

// MARK: - Color Wheel Model

/// Модель цветового колеса для коррекции
class ColorWheel: ObservableObject {
    
    /// Lift (поднятие) - влияет на все тона, но больше на тени
    @Published var lift: SIMD2<Float> = SIMD2<Float>(0, 0)
    
    /// Gamma (гамма) - влияет на средние тона
    @Published var gamma: SIMD2<Float> = SIMD2<Float>(0, 0)
    
    /// Gain (усиление) - влияет на все тона, но больше на света
    @Published var gain: SIMD2<Float> = SIMD2<Float>(0, 0)
    
    /// Offset (смещение) - равномерно влияет на все тона
    @Published var offset: SIMD2<Float> = SIMD2<Float>(0, 0)
    
    /// Сила воздействия колеса
    @Published var strength: Float = 1.0
    
    /// Сбрасывает все значения к нейтральным
    func reset() {
        lift = SIMD2<Float>(0, 0)
        gamma = SIMD2<Float>(0, 0)
        gain = SIMD2<Float>(0, 0)
        offset = SIMD2<Float>(0, 0)
        strength = 1.0
    }
}

// MARK: - Supporting Types

enum ColorCorrectionPreset: CaseIterable {
    case neutral
    case warmTone
    case coolTone
    case vintage
    case dramatic
    
    var displayName: String {
        switch self {
        case .neutral: return "Neutral"
        case .warmTone: return "Warm Tone"
        case .coolTone: return "Cool Tone"
        case .vintage: return "Vintage"
        case .dramatic: return "Dramatic"
        }
    }
}

// MARK: - SwiftUI Preview Support

#if DEBUG
extension ColorWheelsNode {
    static var preview: ColorWheelsNode {
        let node = ColorWheelsNode(position: CGPoint(x: 100, y: 100))
        node.applyPreset(.warmTone)
        return node
    }
}
#endif
