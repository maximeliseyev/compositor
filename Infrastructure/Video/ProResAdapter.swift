import Foundation
import CoreImage
import AVFoundation

/// Адаптер для работы с ProRes файлами в Domain слое
/// Обеспечивает совместимость с Clean Architecture
class ProResAdapter: ObservableObject {
    
    // MARK: - Properties
    @Published var isProcessing: Bool = false
    @Published var processingProgress: Float = 0.0
    @Published var currentOperation: String = ""
    
    // MARK: - ProRes Detection
    
    /// Проверяет, является ли файл ProRes
    func isProResFile(_ url: URL) -> Bool {
        let pathExtension = url.pathExtension.lowercased()
        
        // ProRes файлы обычно имеют расширение .mov
        if pathExtension == "mov" {
            // Дополнительная проверка через AVAsset для определения кодека
            let asset = AVAsset(url: url)
            
            Task {
                do {
                    let tracks = try await asset.loadTracks(withMediaType: .video)
                    if let videoTrack = tracks.first {
                        let formatDescriptions = try await videoTrack.load(.formatDescriptions)
                        if let formatDescription = formatDescriptions.first {
                            let codecType = CMFormatDescriptionGetMediaSubType(formatDescription)
                            
                            // Проверяем ProRes кодеки
                            let proResCodecs: [FourCharCode] = [
                                0x61703434, // 'ap44' - ProRes 4444
                                0x61706871, // 'aphq' - ProRes 422 HQ
                                0x61703232, // 'ap22' - ProRes 422
                                0x61706c74, // 'aplt' - ProRes 422 LT
                                0x61707078  // 'appx' - ProRes 422 Proxy
                            ]
                            
                            if proResCodecs.contains(codecType) {
                                await MainActor.run {
                                    print("🎬 ProResAdapter: ProRes variant detected")
                                }
                            }
                        }
                    }
                } catch {
                    print("⚠️ ProResAdapter: Error checking ProRes codec: \(error)")
                }
            }
            
            return true
        }
        
        return false
    }
    
    /// Определяет вариант ProRes по кодеку
    func getProResVariantString(from codecType: FourCharCode) -> String {
        switch codecType {
        case 0x61703434: return "ProRes 4444" // 'ap44'
        case 0x61706871: return "ProRes 422 HQ" // 'aphq'
        case 0x61703232: return "ProRes 422" // 'ap22'
        case 0x61706c74: return "ProRes 422 LT" // 'aplt'
        case 0x61707078: return "ProRes 422 Proxy" // 'appx'
        default: return "ProRes 422 HQ"
        }
    }
    
    /// Получает информацию о ProRes файле
    func getProResInfo(for url: URL) async -> ProResFileInfo? {
        let asset = AVAsset(url: url)
        
        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let videoTrack = tracks.first else { return nil }
            
            let formatDescriptions = try await videoTrack.load(.formatDescriptions)
            guard let formatDescription = formatDescriptions.first else { return nil }
            
            let codecType = CMFormatDescriptionGetMediaSubType(formatDescription)
            let duration = try await asset.load(.duration)
            let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
            
            return ProResFileInfo(
                variant: getProResVariantString(from: codecType),
                duration: CMTimeGetSeconds(duration),
                frameRate: Double(nominalFrameRate),
                codecType: codecType
            )
        } catch {
            print("❌ ProResAdapter: Error getting ProRes info: \(error)")
            return nil
        }
    }
    
    /// Получает кадры из ProRes файла (упрощенная версия)
    func extractFrames(from url: URL, maxFrames: Int = 30) async -> [CIImage] {
        await MainActor.run {
            isProcessing = true
            currentOperation = "Extracting ProRes frames"
            processingProgress = 0.0
        }
        
        defer {
            Task { @MainActor in
                isProcessing = false
                processingProgress = 0.0
            }
        }
        
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.requestedTimeToleranceBefore = .zero
        
        var frames: [CIImage] = []
        
        do {
            let duration = try await asset.load(.duration)
            let totalSeconds = CMTimeGetSeconds(duration)
            let frameCount = min(maxFrames, Int(totalSeconds * 30)) // 30fps estimate
            
            for i in 0..<frameCount {
                let time = CMTime(seconds: Double(i) * totalSeconds / Double(frameCount), preferredTimescale: 600)
                
                do {
                    let cgImage = try await imageGenerator.image(at: time).image
                    let ciImage = CIImage(cgImage: cgImage)
                    frames.append(ciImage)
                    
                    await MainActor.run {
                        processingProgress = Float(i + 1) / Float(frameCount)
                    }
                } catch {
                    print("⚠️ ProResAdapter: Error extracting frame \(i): \(error)")
                }
            }
        } catch {
            print("❌ ProResAdapter: Error extracting frames: \(error)")
        }
        
        print("✅ ProResAdapter: Extracted \(frames.count) frames")
        return frames
    }
}

// MARK: - Supporting Types

struct ProResFileInfo {
    let variant: String
    let duration: Double
    let frameRate: Double
    let codecType: FourCharCode
    
    var description: String {
        return """
        ProRes File Info:
        - Variant: \(variant)
        - Duration: \(String(format: "%.2f", duration))s
        - Frame Rate: \(String(format: "%.1f", frameRate)) fps
        - Codec: \(String(format: "0x%08X", codecType))
        """
    }
}
