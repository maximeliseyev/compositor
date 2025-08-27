import SwiftUI
import CoreImage
import Metal

class BlurNode: MetalNode {
    
    @Published var radius: Float = 5.0 {
        didSet {
            parameters["radius"] = radius
        }
    }
    
    override init(type: NodeType = .blur, position: CGPoint) {
        super.init(type: type, position: position)
        setupBlurNode()
    }
    
    private func setupBlurNode() {
        // Initialize parameters (ports are created automatically from metadata)
        parameters["radius"] = radius
        parameters["blurType"] = "gaussian"
        
        print("🌫️ OptimizedBlurNode initialized")
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
            print("❗ Optimized Metal blur failed, using Core Image: \(error)")
            return processWithCoreImage(inputs: [inputImage])
        }
    }
    
    override func processWithCoreImage(inputs: [CIImage?]) -> CIImage? {
        guard let inputImage = inputs.first else { return nil }
        
        // Используем Core Image Gaussian Blur
        let filter = CIFilter(name: "CIGaussianBlur")
        filter?.setValue(inputImage, forKey: kCIInputImageKey)
        filter?.setValue(radius, forKey: kCIInputRadiusKey)
        
        return filter?.outputImage ?? inputImage
    }
}
