import Foundation
import Metal
import MetalPerformanceShaders
import CoreImage

/// High-performance processor using Metal Performance Shaders
/// Provides optimized implementations of common image processing operations
class MPSProcessor: ObservableObject {
    
    // MARK: - Metal Resources
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let ciContext: CIContext
    
    // MARK: - MPS Objects Cache
    private var mpsCache: [String: Any] = [:]
    private let cacheQueue = DispatchQueue(label: "com.compositor.mps.cache", attributes: .concurrent)
    
    // MARK: - Performance Tracking
    @Published var isReady: Bool = false
    @Published var lastProcessingTime: TimeInterval = 0.0
    @Published var totalOperationsProcessed: Int = 0
    
    // MARK: - Initialization
    init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        self.device = device
        self.commandQueue = commandQueue
        self.ciContext = CIContext(mtlDevice: device)
        
        setupMPSObjects()
        self.isReady = true
        
        print("🚀 MPS Processor initialized")
        print("📱 Device: \(device.name)")
        print("⚡ MPS Support: \(device.supportsFamily(.apple7) ? "Advanced" : "Basic")")
    }
    
    // MARK: - Setup
    private func setupMPSObjects() {
        // Pre-create commonly used MPS objects for better performance
        // Use sync to avoid actor isolation issues
        cacheQueue.sync(flags: .barrier) {
            // Blur kernels
            mpsCache["gaussianBlur"] = MPSImageGaussianBlur(device: device, sigma: 1.0)
            
            // Convolution
            mpsCache["convolution3x3"] = MPSImageConvolution(
                device: device,
                kernelWidth: 3,
                kernelHeight: 3,
                weights: [0, -1, 0, -1, 5, -1, 0, -1, 0] // Sharpen kernel
            )
            
            // Histogram operations
            if device.supportsFamily(.apple4) {
                mpsCache["histogramEqualization"] = MPSImageHistogramEqualization(device: device)
            }
            
            // Morphological operations
            mpsCache["erosion"] = MPSImageAreaMin(device: device, kernelWidth: 3, kernelHeight: 3)
            mpsCache["dilation"] = MPSImageAreaMax(device: device, kernelWidth: 3, kernelHeight: 3)
        }
    }
    
    // MARK: - Processing Operations
    
    /// High-performance Gaussian blur using MPS
    func gaussianBlur(_ image: CIImage, radius: Float) async throws -> CIImage {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        return try await withCheckedThrowingContinuation { continuation in
            guard let cgImage = ciContext.createCGImage(image, from: image.extent) else {
                continuation.resume(throwing: MPSError.imageConversionFailed)
                return
            }
            
            guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                continuation.resume(throwing: MPSError.commandBufferCreationFailed)
                return
            }
            
            // Create MPS Gaussian Blur with specified radius
            let blur = MPSImageGaussianBlur(device: device, sigma: radius)
            
            // Create textures
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm,
                width: Int(image.extent.width),
                height: Int(image.extent.height),
                mipmapped: false
            )
            textureDescriptor.usage = [.shaderRead, .shaderWrite]
            
            guard let inputTexture = device.makeTexture(descriptor: textureDescriptor),
                  let outputTexture = device.makeTexture(descriptor: textureDescriptor) else {
                continuation.resume(throwing: MPSError.textureCreationFailed)
                return
            }
            
            // Copy CGImage to input texture
            let region = MTLRegionMake2D(0, 0, Int(image.extent.width), Int(image.extent.height))
            let bytesPerRow = 4 * Int(image.extent.width)
            
            // Convert CGImage to raw bytes
            guard let data = cgImage.dataProvider?.data,
                  let bytes = CFDataGetBytePtr(data) else {
                continuation.resume(throwing: MPSError.imageDataExtractionFailed)
                return
            }
            
            inputTexture.replace(region: region, mipmapLevel: 0, withBytes: bytes, bytesPerRow: bytesPerRow)
            
            // Encode blur operation
            blur.encode(commandBuffer: commandBuffer, sourceTexture: inputTexture, destinationTexture: outputTexture)
            
            commandBuffer.addCompletedHandler { [weak self] _ in
                // Convert result back to CIImage
                let ciImage = CIImage(mtlTexture: outputTexture, options: nil) ?? image
                
                // Update performance metrics on main actor
                Task { @MainActor in
                    self?.lastProcessingTime = CFAbsoluteTimeGetCurrent() - startTime
                    self?.totalOperationsProcessed += 1
                }
                
                continuation.resume(returning: ciImage)
            }
            
            commandBuffer.commit()
        }
    }
    
    /// Advanced convolution operation
    func convolution(_ image: CIImage, kernel: [Float], kernelWidth: Int, kernelHeight: Int) async throws -> CIImage {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        return try await withCheckedThrowingContinuation { continuation in
            guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                continuation.resume(throwing: MPSError.commandBufferCreationFailed)
                return
            }
            
            // Create custom convolution kernel
            let convolution = MPSImageConvolution(
                device: device,
                kernelWidth: kernelWidth,
                kernelHeight: kernelHeight,
                weights: kernel
            )
            
            // Convert CIImage to MTLTexture and process
            processWithMPSKernel(convolution, image: image, commandBuffer: commandBuffer) { [weak self] result in
                // Update performance metrics on main actor
                Task { @MainActor in
                    self?.lastProcessingTime = CFAbsoluteTimeGetCurrent() - startTime
                    self?.totalOperationsProcessed += 1
                }
                continuation.resume(returning: result)
            }
        }
    }
    
    /// Histogram equalization for automatic contrast enhancement
    func histogramEqualization(_ image: CIImage) async throws -> CIImage {
        guard device.supportsFamily(.apple4) else {
            throw MPSError.operationNotSupported("Histogram equalization requires A11 or newer")
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        return try await withCheckedThrowingContinuation { continuation in
            guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                continuation.resume(throwing: MPSError.commandBufferCreationFailed)
                return
            }
            
            let histogramEq = MPSImageHistogramEqualization(device: device)
            
            processWithMPSKernel(histogramEq, image: image, commandBuffer: commandBuffer) { [weak self] result in
                // Update performance metrics on main actor
                Task { @MainActor in
                    self?.lastProcessingTime = CFAbsoluteTimeGetCurrent() - startTime
                    self?.totalOperationsProcessed += 1
                }
                continuation.resume(returning: result)
            }
        }
    }
    
    /// Morphological operations (erosion/dilation)
    func morphology(_ image: CIImage, operation: MorphologyOperation, kernelSize: Int) async throws -> CIImage {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        return try await withCheckedThrowingContinuation { continuation in
            guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                continuation.resume(throwing: MPSError.commandBufferCreationFailed)
                return
            }
            
            let morphKernel: MPSUnaryImageKernel
            switch operation {
            case .erosion:
                morphKernel = MPSImageAreaMin(device: device, kernelWidth: kernelSize, kernelHeight: kernelSize)
            case .dilation:
                morphKernel = MPSImageAreaMax(device: device, kernelWidth: kernelSize, kernelHeight: kernelSize)
            case .opening:
                // Opening = Erosion followed by Dilation
                // For now, just do erosion (can be extended to chain operations)
                morphKernel = MPSImageAreaMin(device: device, kernelWidth: kernelSize, kernelHeight: kernelSize)
            case .closing:
                // Closing = Dilation followed by Erosion
                morphKernel = MPSImageAreaMax(device: device, kernelWidth: kernelSize, kernelHeight: kernelSize)
            }
            
            processWithMPSKernel(morphKernel, image: image, commandBuffer: commandBuffer) { [weak self] result in
                // Update performance metrics on main actor
                Task { @MainActor in
                    self?.lastProcessingTime = CFAbsoluteTimeGetCurrent() - startTime
                    self?.totalOperationsProcessed += 1
                }
                continuation.resume(returning: result)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func processWithMPSKernel(_ kernel: MPSUnaryImageKernel, 
                                      image: CIImage, 
                                      commandBuffer: MTLCommandBuffer,
                                      completion: @escaping (CIImage) -> Void) {
        
        // Create temporary texture for MPS processing
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float, // Use 16-bit float for better precision
            width: Int(image.extent.width),
            height: Int(image.extent.height),
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let inputTexture = device.makeTexture(descriptor: textureDescriptor),
              let outputTexture = device.makeTexture(descriptor: textureDescriptor) else {
            completion(image) // Fallback to original
            return
        }
        
        // Convert CIImage to MTLTexture
        ciContext.render(image, to: inputTexture, commandBuffer: commandBuffer, bounds: image.extent, colorSpace: CGColorSpaceCreateDeviceRGB())
        
        // Apply MPS kernel
        kernel.encode(commandBuffer: commandBuffer, sourceTexture: inputTexture, destinationTexture: outputTexture)
        
        commandBuffer.addCompletedHandler { _ in
            // Convert back to CIImage
            let resultImage = CIImage(mtlTexture: outputTexture, options: [
                .colorSpace: CGColorSpaceCreateDeviceRGB()
            ]) ?? image
            
            completion(resultImage)
        }
        
        commandBuffer.commit()
    }
    
    // MARK: - Performance Info
    
    func getPerformanceInfo() -> String {
        return """
        🚀 MPS Processor Status:
           Ready: \(isReady ? "Yes" : "No")
           Operations Processed: \(totalOperationsProcessed)
           Last Processing Time: \(String(format: "%.2f", lastProcessingTime * 1000))ms
           Device Support: \(device.supportsFamily(.apple7) ? "Advanced MPS" : "Basic MPS")
           Cache Size: \(mpsCache.count) objects
        """
    }
}

// MARK: - Supporting Types

enum MorphologyOperation {
    case erosion
    case dilation
    case opening
    case closing
}

enum MPSError: LocalizedError {
    case imageConversionFailed
    case commandBufferCreationFailed
    case textureCreationFailed
    case imageDataExtractionFailed
    case operationNotSupported(String)
    
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert CIImage to CGImage"
        case .commandBufferCreationFailed:
            return "Failed to create Metal command buffer"
        case .textureCreationFailed:
            return "Failed to create Metal texture"
        case .imageDataExtractionFailed:
            return "Failed to extract image data"
        case .operationNotSupported(let operation):
            return "Operation not supported: \(operation)"
        }
    }
}
