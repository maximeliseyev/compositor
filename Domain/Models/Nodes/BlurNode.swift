import SwiftUI
import CoreImage

class BlurNode: CoreImageNode {
    
    // MARK: - Blur Parameters
    @Published var radius: Float = 5.0 {
        didSet {
            parameters["radius"] = radius
            invalidateCache()
        }
    }
    
    @Published var blurType: String = "gaussian" {
        didSet {
            parameters["blurType"] = blurType
            invalidateCache()
        }
    }
    
    // MARK: - Initialization
    override init(type: NodeType = .blur, position: CGPoint) {
        super.init(type: type, position: position)
        setupBlurNode()
    }
    
    private func setupBlurNode() {
        // Initialize parameters
        parameters["radius"] = radius
        parameters["blurType"] = blurType
        
        print("🌫️ BlurNode initialized with Core Image")
    }
    
    // MARK: - Core Image Processing
    
    override func processWithCoreImage(inputs: [CIImage?]) -> CIImage? {
        guard let inputImage = inputs.first else { return nil }
        
        // Выбираем фильтр в зависимости от типа размытия
        let filterName: String
        switch blurType.lowercased() {
        case "gaussian":
            filterName = "CIGaussianBlur"
        case "box":
            filterName = "CIBoxBlur"
        case "disc":
            filterName = "CIDiscBlur"
        case "motion":
            filterName = "CIMotionBlur"
        default:
            filterName = "CIGaussianBlur"
        }
        
        // Получаем или создаем фильтр
        guard let filter = getOrCreateFilter(name: filterName) else {
            print("⚠️ Failed to create filter: \(filterName)")
            return inputImage
        }
        
        // Настраиваем фильтр
        filter.setValue(inputImage, forKey: kCIInputImageKey)
        
        // Устанавливаем параметры в зависимости от типа фильтра
        switch filterName {
        case "CIGaussianBlur":
            filter.setValue(radius, forKey: kCIInputRadiusKey)
        case "CIBoxBlur":
            filter.setValue(radius, forKey: kCIInputRadiusKey)
        case "CIDiscBlur":
            filter.setValue(radius, forKey: kCIInputRadiusKey)
        case "CIMotionBlur":
            filter.setValue(radius, forKey: kCIInputRadiusKey)
            // Для motion blur можно добавить направление
            filter.setValue(0.0, forKey: kCIInputAngleKey)
        default:
            filter.setValue(radius, forKey: kCIInputRadiusKey)
        }
        
        // Получаем результат
        guard let outputImage = filter.outputImage else {
            print("⚠️ Filter output is nil for: \(filterName)")
            return inputImage
        }
        
        return outputImage
    }
    
    // MARK: - Parameter Management
    
    /// Устанавливает тип размытия
    func setBlurType(_ type: String) {
        blurType = type
    }
    
    /// Получает доступные типы размытия
    func getAvailableBlurTypes() -> [String] {
        return ["gaussian", "box", "disc", "motion"]
    }
    
    // MARK: - Performance Info Override
    
    override func getPerformanceInfo() -> String {
        let baseInfo = super.getPerformanceInfo()
        return """
        \(baseInfo)
        Blur type: \(blurType)
        Radius: \(radius)
        """
    }
}
