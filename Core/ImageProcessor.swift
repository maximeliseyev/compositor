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
    
    private func applyFilter(_ filter: ImageFilter, to image: CIImage) -> CIImage {
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
    
    // Конвертация CIImage в NSImage
    func ciImageToNSImage(_ ciImage: CIImage) -> NSImage? {
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}

// Структура для описания фильтра
struct ImageFilter: Identifiable {
    let id = UUID()
    let name: String
    let type: FilterType
    var parameters: [String: Double]
    var isEnabled: Bool = true
}

enum FilterType: String, CaseIterable {
    case colorControls = "Color Controls"
    case blur = "Blur"
    case sharpen = "Sharpen"
    case exposure = "Exposure"
}