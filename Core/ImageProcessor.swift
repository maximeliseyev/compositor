//
//  ImageProcessor.swift
//  Compositor
//
//  Enhanced with public filter methods
//

import CoreImage
import CoreImage.CIFilterBuiltins
import AppKit

class ImageProcessor: ObservableObject {
    private let context = CIContext()
    
    // Применение множественных фильтров
    func applyFilters(to image: CIImage, filters: [ImageFilter]) -> CIImage {
        var processedImage = image
        
        for filter in filters {
            processedImage = applyFilter(filter, to: processedImage)
        }
        
        return processedImage
    }
    
    // Публичный метод для применения одного фильтра
    func applyFilter(_ filter: ImageFilter, to image: CIImage) -> CIImage {
        switch filter.type {
        case .colorControls:
            return applyColorControls(to: image, filter: filter)
        case .blur:
            return applyBlur(to: image, filter: filter)
        case .sharpen:
            return applySharpen(to: image, filter: filter)
        case .exposure:
            return applyExposure(to: image, filter: filter)
        }
    }
    
    private func applyColorControls(to image: CIImage, filter: ImageFilter) -> CIImage {
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = image
        colorFilter.brightness = Float(filter.parameters["brightness"] ?? 0.0)
        colorFilter.contrast = Float(filter.parameters["contrast"] ?? 1.0)
        colorFilter.saturation = Float(filter.parameters["saturation"] ?? 1.0)
        return colorFilter.outputImage ?? image
    }
    
    private func applyBlur(to image: CIImage, filter: ImageFilter) -> CIImage {
        let blurFilter = CIFilter.gaussianBlur()
        blurFilter.inputImage = image
        blurFilter.radius = Float(filter.parameters["radius"] ?? 0.0)
        return blurFilter.outputImage ?? image
    }
    
    private func applySharpen(to image: CIImage, filter: ImageFilter) -> CIImage {
        let sharpenFilter = CIFilter.unsharpMask()
        sharpenFilter.inputImage = image
        sharpenFilter.radius = Float(filter.parameters["radius"] ?? 2.5)
        sharpenFilter.intensity = Float(filter.parameters["intensity"] ?? 0.5)
        return sharpenFilter.outputImage ?? image
    }
    
    private func applyExposure(to image: CIImage, filter: ImageFilter) -> CIImage {
        let exposureFilter = CIFilter.exposureAdjust()
        exposureFilter.inputImage = image
        exposureFilter.ev = Float(filter.parameters["exposure"] ?? 0.0)
        return exposureFilter.outputImage ?? image
    }
    
    // Дополнительные фильтры для расширения функциональности
    func applyVignette(to image: CIImage, intensity: Float = 1.0, radius: Float = 1.0) -> CIImage {
        let vignetteFilter = CIFilter.vignette()
        vignetteFilter.inputImage = image
        vignetteFilter.intensity = intensity
        vignetteFilter.radius = radius
        return vignetteFilter.outputImage ?? image
    }
    
    func applyHueAdjust(to image: CIImage, angle: Float = 0.0) -> CIImage {
        let hueFilter = CIFilter.hueAdjust()
        hueFilter.inputImage = image
        hueFilter.angle = angle
        return hueFilter.outputImage ?? image
    }
    
    func applyGammaAdjust(to image: CIImage, power: Float = 1.0) -> CIImage {
        let gammaFilter = CIFilter.gammaAdjust()
        gammaFilter.inputImage = image
        gammaFilter.power = power
        return gammaFilter.outputImage ?? image
    }
    
    // Конвертация CIImage в NSImage
    func ciImageToNSImage(_ ciImage: CIImage) -> NSImage? {
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
    
    // Получение информации об изображении
    func getImageInfo(_ image: CIImage) -> String {
        let extent = image.extent
        return "Size: \(Int(extent.width)) x \(Int(extent.height))"
    }
}

// Структура для описания фильтра
struct ImageFilter: Identifiable {
    let id = UUID()
    let name: String
    let type: FilterType
    var parameters: [String: Double]
    var isEnabled: Bool = true
    
    init(name: String, type: FilterType, parameters: [String: Double]) {
        self.name = name
        self.type = type
        self.parameters = parameters
    }
}

enum FilterType: String, CaseIterable {
    case colorControls = "Color Controls"
    case blur = "Blur"
    case sharpen = "Sharpen"
    case exposure = "Exposure"
    case vignette = "Vignette"
    case hueAdjust = "Hue Adjust"
    case gammaAdjust = "Gamma Adjust"
}
