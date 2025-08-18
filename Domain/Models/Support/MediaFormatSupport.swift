import Foundation
import CoreImage
import AVFoundation
import UniformTypeIdentifiers

// MARK: - Media Format Types
/// Универсальная система поддержки медиа-форматов
public enum MediaFormat: String, CaseIterable {
    // MARK: - Image Formats
    case dpx = "DPX"
    case exr = "EXR"
    case tiff = "TIFF"
    case png = "PNG"
    case jpeg = "JPEG"
    case jpg = "JPG"
    
    // MARK: - Video Formats
    case mov = "MOV"
    case mp4 = "MP4"
    case avi = "AVI"
    case mkv = "MKV"
    case webm = "WEBM"
    case m4v = "M4V"
    
    // MARK: - ProRes Variants (подмножество видео)
    case proRes4444 = "ProRes 4444"
    case proRes422HQ = "ProRes 422 HQ"
    case proRes422 = "ProRes 422"
    case proRes422LT = "ProRes 422 LT"
    case proRes422Proxy = "ProRes 422 Proxy"
    
    // MARK: - Properties
    public var isImage: Bool {
        switch self {
        case .dpx, .exr, .tiff, .png, .jpeg, .jpg:
            return true
        default:
            return false
        }
    }
    
    public var isVideo: Bool {
        switch self {
        case .mov, .mp4, .avi, .mkv, .webm, .m4v:
            return true
        default:
            return false
        }
    }
    
    public var isProRes: Bool {
        switch self {
        case .proRes4444, .proRes422HQ, .proRes422, .proRes422LT, .proRes422Proxy:
            return true
        default:
            return false
        }
    }
    
    public var fileExtensions: [String] {
        switch self {
        case .dpx: return ["dpx"]
        case .exr: return ["exr"]
        case .tiff: return ["tiff", "tif"]
        case .png: return ["png"]
        case .jpeg, .jpg: return ["jpeg", "jpg"]
        case .mov: return ["mov"]
        case .mp4: return ["mp4"]
        case .avi: return ["avi"]
        case .mkv: return ["mkv"]
        case .webm: return ["webm"]
        case .m4v: return ["m4v"]
        case .proRes4444, .proRes422HQ, .proRes422, .proRes422LT, .proRes422Proxy:
            return ["mov"] // ProRes использует .mov контейнер
        }
    }
    
    public var description: String {
        switch self {
        case .dpx: return "Digital Picture Exchange - High quality image sequence"
        case .exr: return "OpenEXR - High dynamic range image format"
        case .tiff: return "Tagged Image File Format - Professional image format"
        case .png: return "Portable Network Graphics - Lossless image format"
        case .jpeg, .jpg: return "JPEG - Compressed image format"
        case .mov: return "QuickTime Movie - Apple video container"
        case .mp4: return "MPEG-4 - Standard video container"
        case .avi: return "Audio Video Interleave - Microsoft video container"
        case .mkv: return "Matroska - Open video container"
        case .webm: return "WebM - Web-optimized video format"
        case .m4v: return "iTunes Video - Apple video format"
        case .proRes4444: return "ProRes 4444 - Highest quality, 4:4:4 chroma, 12-bit, alpha channel"
        case .proRes422HQ: return "ProRes 422 HQ - High quality, 4:2:2 chroma, 10-bit, broadcast standard"
        case .proRes422: return "ProRes 422 - Standard quality, 4:2:2 chroma, 10-bit, balanced"
        case .proRes422LT: return "ProRes 422 LT - Lightweight, 4:2:2 chroma, 10-bit, efficient"
        case .proRes422Proxy: return "ProRes 422 Proxy - Proxy quality, 4:2:2 chroma, 10-bit, fast editing"
        }
    }
    
    public var isProfessional: Bool {
        switch self {
        case .dpx, .exr, .tiff, .proRes4444, .proRes422HQ, .proRes422, .proRes422LT, .proRes422Proxy:
            return true
        default:
            return false
        }
    }
}

// MARK: - Media Format Detection
public class MediaFormatDetector {
    
    /// Определяет формат медиафайла по URL
    public static func detectFormat(for url: URL) async -> MediaFormat? {
        let pathExtension = url.pathExtension.lowercased()
        
        // Сначала проверяем по расширению
        for format in MediaFormat.allCases {
            if format.fileExtensions.contains(pathExtension) {
                // Для .mov файлов нужна дополнительная проверка на ProRes
                if pathExtension == "mov" {
                    return await detectProResVariant(for: url) ?? .mov
                }
                return format
            }
        }
        
        return nil
    }
    
    /// Определяет вариант ProRes в .mov файле
    private static func detectProResVariant(for url: URL) async -> MediaFormat? {
        let asset = AVAsset(url: url)
        
        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let videoTrack = tracks.first else { return nil }
            
            let formatDescriptions = try await videoTrack.load(.formatDescriptions)
            guard let formatDescription = formatDescriptions.first else { return nil }
            
            let codecType = CMFormatDescriptionGetMediaSubType(formatDescription)
            
            // ProRes кодеки
            switch codecType {
            case 0x61703434: return .proRes4444 // 'ap44'
            case 0x61706871: return .proRes422HQ // 'aphq'
            case 0x61703232: return .proRes422 // 'ap22'
            case 0x61706c74: return .proRes422LT // 'aplt'
            case 0x61707078: return .proRes422Proxy // 'appx'
            default: return nil
            }
        } catch {
            print("⚠️ MediaFormatDetector: Error detecting ProRes variant: \(error)")
            return nil
        }
    }
    
    /// Проверяет, поддерживается ли формат
    public static func isFormatSupported(_ format: MediaFormat) -> Bool {
        // Все форматы поддерживаются, но некоторые могут требовать дополнительных библиотек
        return true
    }
}

// MARK: - Media File Information
public struct MediaFileInfo {
    public let format: MediaFormat
    public let url: URL
    public let fileSize: Int64
    public let duration: Double?
    public let frameRate: Double?
    public let resolution: CGSize?
    public let bitDepth: Int?
    public let hasAlpha: Bool
    
    public init(format: MediaFormat, url: URL, fileSize: Int64, duration: Double? = nil, 
                frameRate: Double? = nil, resolution: CGSize? = nil, bitDepth: Int? = nil, hasAlpha: Bool = false) {
        self.format = format
        self.url = url
        self.fileSize = fileSize
        self.duration = duration
        self.frameRate = frameRate
        self.resolution = resolution
        self.bitDepth = bitDepth
        self.hasAlpha = hasAlpha
    }
}

// MARK: - Media Processing Protocol
public protocol MediaProcessing {
    /// Загружает медиафайл и возвращает информацию о нем
    func loadMedia(from url: URL) async throws -> MediaFileInfo
    
    /// Извлекает кадры из медиафайла
    func extractFrames(from url: URL, maxFrames: Int?) async throws -> [CIImage]
    
    /// Сохраняет кадры в указанный формат
    func saveFrames(_ frames: [CIImage], to url: URL, format: MediaFormat) async throws
    
    /// Конвертирует медиафайл в другой формат
    func convertMedia(from sourceURL: URL, to destinationURL: URL, targetFormat: MediaFormat) async throws
}

// MARK: - Media Format Categories
public enum MediaCategory {
    case image
    case video
    case proRes
    
    public var formats: [MediaFormat] {
        switch self {
        case .image:
            return MediaFormat.allCases.filter { $0.isImage }
        case .video:
            return MediaFormat.allCases.filter { $0.isVideo && !$0.isProRes }
        case .proRes:
            return MediaFormat.allCases.filter { $0.isProRes }
        }
    }
    
    public var displayName: String {
        switch self {
        case .image: return "Images"
        case .video: return "Video"
        case .proRes: return "ProRes"
        }
    }
}
