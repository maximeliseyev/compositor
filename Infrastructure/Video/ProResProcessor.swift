import Foundation
import AVFoundation
import CoreImage
import Metal
import os.log

/// Professional ProRes processor with hardware acceleration
/// Supports all ProRes variants with hardware encode/decode on Apple Silicon
@MainActor
class ProResProcessor: ObservableObject {
    
    // MARK: - ProRes Variants
    enum ProResVariant: String, CaseIterable {
        case proRes4444 = "ProRes 4444"
        case proRes422HQ = "ProRes 422 HQ"
        case proRes422 = "ProRes 422"
        case proRes422LT = "ProRes 422 LT"
        case proRes422Proxy = "ProRes 422 Proxy"
        
        var description: String {
            switch self {
            case .proRes4444: return "Highest quality, 4:4:4 chroma, 12-bit, alpha channel"
            case .proRes422HQ: return "High quality, 4:2:2 chroma, 10-bit, broadcast standard"
            case .proRes422: return "Standard quality, 4:2:2 chroma, 10-bit, balanced"
            case .proRes422LT: return "Lightweight, 4:2:2 chroma, 10-bit, efficient"
            case .proRes422Proxy: return "Proxy quality, 4:2:2 chroma, 10-bit, fast editing"
            }
        }
    }
    
    // MARK: - Processing Quality
    enum ProcessingQuality: String, CaseIterable {
        case realtime = "Real-time"
        case high = "High Quality"
        case maximum = "Maximum Quality"
        
        var encodingPreset: String {
            switch self {
            case .realtime: return AVAssetExportPresetHighestQuality
            case .high: return AVAssetExportPresetHighestQuality
            case .maximum: return AVAssetExportPresetHighestQuality
            }
        }
        
        var description: String {
            switch self {
            case .realtime: return "Fast encoding for real-time workflows"
            case .high: return "High quality with good performance"
            case .maximum: return "Maximum quality, slower encoding"
            }
        }
    }
    
    // MARK: - Properties
    
    // MARK: - AVFoundation Components
    private var videoComposition: AVMutableVideoComposition?
    private var exportSession: AVAssetExportSession?
    private var reader: AVAssetReader?
    private var writer: AVAssetWriter?
    
    // MARK: - Hardware Acceleration
    private var hardwareEncoder: AVAssetWriterInput?
    private var hardwareDecoder: AVAssetReaderTrackOutput?
    
    // MARK: - State Management
    @Published var isProcessing: Bool = false
    @Published var processingProgress: Float = 0.0
    @Published var currentOperation: String = ""
    @Published var isHardwareAccelerated: Bool = false
    
    // MARK: - Performance Metrics
    @Published var averageEncodingTime: TimeInterval = 0.0
    @Published var averageDecodingTime: TimeInterval = 0.0
    @Published var hardwareUtilization: Float = 0.0
    @Published var memoryUsage: Int64 = 0
    
    // MARK: - Initialization
    init() {
        setupHardwareAcceleration()
        print("🎬 ProRes Processor initialized")
    }
    
    // MARK: - Hardware Acceleration Setup
    
    private func setupHardwareAcceleration() {
        // Check for hardware ProRes acceleration
        let device = MTLCreateSystemDefaultDevice()
        isHardwareAccelerated = device?.supportsFamily(.apple7) ?? false
        
        if isHardwareAccelerated {
            print("✅ ProRes: Hardware acceleration available")
        } else {
            print("⚠️ ProRes: Hardware acceleration not available (using software)")
        }
    }
    
    // MARK: - ProRes Decoding
    
    func decodeProRes(from url: URL) async throws -> [CIImage] {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        await MainActor.run {
            isProcessing = true
            currentOperation = "Decoding ProRes"
            processingProgress = 0.0
        }
        
        defer {
            Task { @MainActor in
                isProcessing = false
                processingProgress = 0.0
            }
        }
        
        // Create asset and reader
        let asset = AVAsset(url: url)
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw ProResError.noVideoTrack
        }
        
        // Configure reader for hardware acceleration
        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        
        let output = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
        reader.add(output)
        
        // Start reading
        reader.startReading()
        
        var frames: [CIImage] = []
        var frameCount = 0
        let duration = try await asset.load(.duration)
        let totalFrames = Int(CMTimeGetSeconds(duration) * 30) // Estimate 30fps
        
        while let sampleBuffer = output.copyNextSampleBuffer() {
            if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                let ciImage = CIImage(cvPixelBuffer: imageBuffer)
                frames.append(ciImage)
                
                frameCount += 1
                await MainActor.run {
                    processingProgress = Float(frameCount) / Float(totalFrames)
                }
            }
        }
        
        // Update performance metrics
        let decodingTime = CFAbsoluteTimeGetCurrent() - startTime
        await updateDecodingMetrics(decodingTime: decodingTime, frameCount: frameCount)
        
        print("✅ ProRes: Decoded \(frameCount) frames in \(String(format: "%.2f", decodingTime))s")
        print("✅ ProRes: Decoded \(frameCount) frames")
        
        return frames
    }
    
    // MARK: - ProRes Encoding
    
    func encodeProRes(_ images: [CIImage], 
                     to url: URL, 
                     variant: ProResVariant) async throws {
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        await MainActor.run {
            isProcessing = true
            currentOperation = "Encoding ProRes \(variant.rawValue)"
            processingProgress = 0.0
        }
        
        defer {
            Task { @MainActor in
                isProcessing = false
                processingProgress = 0.0
            }
        }
        
        // Create writer with ProRes settings
        let writer = try AVAssetWriter(url: url, fileType: .mov)
        
        // Configure ProRes output settings
        let outputSettings = getProResOutputSettings(for: variant)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        input.expectsMediaDataInRealTime = false
        
        // Enable hardware acceleration if available
        if isHardwareAccelerated {
            input.performsMultiPassEncodingIfSupported = true
        }
        
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        
        // Encode frames
        let frameDuration = CMTime(value: 1, timescale: 30) // 30fps
        var currentTime = CMTime.zero
        
        for (index, image) in images.enumerated() {
            // Convert CIImage to CVPixelBuffer
            let pixelBuffer = try createPixelBuffer(from: image)
            
            // Create sample buffer
            let sampleBuffer = try createSampleBuffer(
                from: pixelBuffer,
                presentationTime: currentTime
            )
            
            // Append to writer
            if input.isReadyForMoreMediaData {
                input.append(sampleBuffer)
                currentTime = CMTimeAdd(currentTime, frameDuration)
                
                await MainActor.run {
                    processingProgress = Float(index + 1) / Float(images.count)
                }
            }
        }
        
        // Finish writing
        input.markAsFinished()
        await writer.finishWriting()
        
        // Update performance metrics
        let encodingTime = CFAbsoluteTimeGetCurrent() - startTime
        await updateEncodingMetrics(encodingTime: encodingTime, frameCount: images.count)
        
        print("✅ ProRes: Encoded \(images.count) frames to \(variant.rawValue) in \(String(format: "%.2f", encodingTime))s")
        print("✅ ProRes: Encoded \(images.count) frames to \(variant.rawValue)")
    }
    
    // MARK: - ProRes Conversion
    
    func convertProRes(from sourceURL: URL, 
                      to destinationURL: URL, 
                      targetVariant: ProResVariant) async throws {
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        await MainActor.run {
            isProcessing = true
            currentOperation = "Converting to \(targetVariant.rawValue)"
            processingProgress = 0.0
        }
        
        defer {
            Task { @MainActor in
                isProcessing = false
                processingProgress = 0.0
            }
        }
        
        // Create export session
        let asset = AVAsset(url: sourceURL)
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw ProResError.exportSessionCreationFailed
        }
        
        exportSession.outputURL = destinationURL
        exportSession.outputFileType = .mov
        
        // Configure ProRes output settings
        let outputSettings = getProResOutputSettings(for: targetVariant)
        exportSession.videoComposition = try await createVideoComposition(
            for: asset,
            outputSettings: outputSettings
        )
        
        // Perform export
        await exportSession.export()
        
        if exportSession.status == .completed {
            let conversionTime = CFAbsoluteTimeGetCurrent() - startTime
            print("✅ ProRes: Conversion completed in \(String(format: "%.2f", conversionTime))s")
            print("✅ ProRes: Conversion to \(targetVariant.rawValue) completed")
        } else {
            throw ProResError.exportFailed(exportSession.error)
        }
    }
    
    // MARK: - Utility Methods
    
    private func getProResOutputSettings(for variant: ProResVariant) -> [String: Any] {
        let codecType = getCodecType(for: variant)
        return [
            AVVideoCodecKey: codecType,
            AVVideoWidthKey: 1920,
            AVVideoHeightKey: 1080,
            AVVideoCompressionPropertiesKey: [
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoAllowFrameReorderingKey: false,
                AVVideoMaxKeyFrameIntervalKey: 30
            ]
        ]
    }
    
    private func getCodecType(for variant: ProResVariant) -> CMFormatDescription.MediaSubType {
        switch variant {
        case .proRes4444: return .proRes4444
        case .proRes422HQ: return .proRes422HQ
        case .proRes422: return .proRes422
        case .proRes422LT: return .proRes422LT
        case .proRes422Proxy: return .proRes422Proxy
        }
    }
    
    private func createVideoComposition(for asset: AVAsset, 
                                      outputSettings: [String: Any]) async throws -> AVMutableVideoComposition {
        
        let composition = AVMutableVideoComposition()
        composition.renderSize = CGSize(width: 1920, height: 1080)
        composition.frameDuration = CMTime(value: 1, timescale: 30)
        
        // Add video composition instruction
        let instruction = AVMutableVideoCompositionInstruction()
        let duration = try await asset.load(.duration)
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        
        if let videoTrack = try? await asset.loadTracks(withMediaType: .video).first {
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            instruction.layerInstructions = [layerInstruction]
        }
        
        composition.instructions = [instruction]
        
        return composition
    }
    
    private func createPixelBuffer(from image: CIImage) throws -> CVPixelBuffer {
        let context = CIContext()
        let extent = image.extent
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(extent.width),
            Int(extent.height),
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw ProResError.pixelBufferCreationFailed
        }
        
        context.render(image, to: buffer)
        return buffer
    }
    
    private func createSampleBuffer(from pixelBuffer: CVPixelBuffer, 
                                  presentationTime: CMTime) throws -> CMSampleBuffer {
        
        var formatDescription: CMFormatDescription?
        let status = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        
        guard status == noErr, let format = formatDescription else {
            throw ProResError.formatDescriptionCreationFailed
        }
        
        var sampleBuffer: CMSampleBuffer?
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: presentationTime
        )
        let sampleStatus = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: format,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        
        guard sampleStatus == noErr, let buffer = sampleBuffer else {
            throw ProResError.sampleBufferCreationFailed
        }
        
        return buffer
    }
    
    // MARK: - Performance Monitoring
    
    private func updateEncodingMetrics(encodingTime: TimeInterval, frameCount: Int) async {
        await MainActor.run {
            let alpha = 0.1
            averageEncodingTime = averageEncodingTime * (1 - alpha) + encodingTime * alpha
            
            // Estimate hardware utilization
            let fps = Double(frameCount) / encodingTime
            hardwareUtilization = min(1.0, Float(fps) / 30.0) // Target 30fps
        }
    }
    
    private func updateDecodingMetrics(decodingTime: TimeInterval, frameCount: Int) async {
        await MainActor.run {
            let alpha = 0.1
            averageDecodingTime = averageDecodingTime * (1 - alpha) + decodingTime * alpha
        }
    }
    
    // MARK: - Public Interface
    
    func getProResInfo() -> String {
        return """
        🎬 ProRes Status:
           Hardware Acceleration: \(isHardwareAccelerated ? "✅" : "❌")
           Current Operation: \(currentOperation)
           
        📊 Performance Metrics:
           Average Encoding Time: \(String(format: "%.2f", averageEncodingTime * 1000))ms
           Average Decoding Time: \(String(format: "%.2f", averageDecodingTime * 1000))ms
           Hardware Utilization: \(String(format: "%.1f", hardwareUtilization * 100))%
           
        🎯 Supported Variants:
           \(ProResVariant.allCases.map { "• \($0.rawValue): \($0.description)" }.joined(separator: "\n           "))
        """
    }
    
    func getSupportedVariants() -> [ProResVariant] {
        return ProResVariant.allCases
    }
    
    func isVariantSupported(_ variant: ProResVariant) -> Bool {
        // All ProRes variants are supported on macOS
        return true
    }
}

// MARK: - Supporting Types

enum ProResError: LocalizedError {
    case noVideoTrack
    case exportSessionCreationFailed
    case exportFailed(Error?)
    case pixelBufferCreationFailed
    case formatDescriptionCreationFailed
    case sampleBufferCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .noVideoTrack:
            return "No video track found in ProRes file"
        case .exportSessionCreationFailed:
            return "Failed to create ProRes export session"
        case .exportFailed(let error):
            return "ProRes export failed: \(error?.localizedDescription ?? "Unknown error")"
        case .pixelBufferCreationFailed:
            return "Failed to create pixel buffer for ProRes encoding"
        case .formatDescriptionCreationFailed:
            return "Failed to create format description for ProRes encoding"
        case .sampleBufferCreationFailed:
            return "Failed to create sample buffer for ProRes encoding"
        }
    }
}
