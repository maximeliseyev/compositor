import Foundation
import CoreImage
import AVFoundation
import UniformTypeIdentifiers

/// Универсальный медиа-процессор для обработки всех форматов
/// Включает ProRes как подмножество видео-форматов
public class UniversalMediaProcessor: ObservableObject, MediaProcessing {
    
    // MARK: - Published Properties
    @Published var isProcessing: Bool = false
    @Published var processingProgress: Float = 0.0
    @Published var currentOperation: String = ""
    @Published var currentFormat: MediaFormat?
    
    // MARK: - Private Properties
    private let imageProcessor = ImageProcessor()
    private let videoProcessor = VideoProcessor()
    private let proResProcessor = ProResProcessorWrapper()
    
    // MARK: - Constants
    private let MAX_FRAME_BUFFER_SIZE = 100
    private let FRAME_EXTRACTION_TIMEOUT: TimeInterval = 30.0
    
    // MARK: - MediaProcessing Implementation
    
    /// Загружает медиафайл и возвращает информацию о нем
    public func loadMedia(from url: URL) async throws -> MediaFileInfo {
        await MainActor.run {
            isProcessing = true
            currentOperation = "Detecting media format..."
        }
        
        guard let format = await MediaFormatDetector.detectFormat(for: url) else {
            throw MediaProcessingError.unsupportedFormat
        }
        
        await MainActor.run {
            currentFormat = format
            currentOperation = "Loading \(format.rawValue) file..."
        }
        
        let fileSize = try await getFileSize(for: url)
        
        // Получаем дополнительную информацию в зависимости от типа
        if format.isImage {
            return try await loadImageInfo(url: url, format: format, fileSize: fileSize)
        } else if format.isVideo || format.isProRes {
            return try await loadVideoInfo(url: url, format: format, fileSize: fileSize)
        } else {
            throw MediaProcessingError.unknownFormat
        }
    }
    
    /// Извлекает кадры из медиафайла
    public func extractFrames(from url: URL, maxFrames: Int? = nil) async throws -> [CIImage] {
        guard let format = await MediaFormatDetector.detectFormat(for: url) else {
            throw MediaProcessingError.unsupportedFormat
        }
        
        await MainActor.run {
            isProcessing = true
            currentOperation = "Extracting frames from \(format.rawValue)..."
        }
        
        let frameLimit = maxFrames ?? MAX_FRAME_BUFFER_SIZE
        
        do {
            let frames: [CIImage]
            
            if format.isImage {
                frames = try await extractImageFrames(from: url, format: format, maxFrames: frameLimit)
            } else if format.isProRes {
                frames = try await extractProResFrames(from: url, maxFrames: frameLimit)
            } else if format.isVideo {
                frames = try await extractVideoFrames(from: url, maxFrames: frameLimit)
            } else {
                throw MediaProcessingError.unsupportedFormat
            }
            
            await MainActor.run {
                isProcessing = false
                processingProgress = 1.0
                currentOperation = "Extracted \(frames.count) frames"
            }
            
            return frames
            
        } catch {
            await MainActor.run {
                isProcessing = false
                processingProgress = 0.0
                currentOperation = "Error: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    /// Сохраняет кадры в указанный формат
    public func saveFrames(_ frames: [CIImage], to url: URL, format: MediaFormat) async throws {
        await MainActor.run {
            isProcessing = true
            currentOperation = "Saving frames as \(format.rawValue)..."
        }
        
        do {
            if format.isImage {
                try await saveImageFrames(frames, to: url, format: format)
            } else if format.isProRes {
                try await saveProResFrames(frames, to: url, format: format)
            } else if format.isVideo {
                try await saveVideoFrames(frames, to: url, format: format)
            } else {
                throw MediaProcessingError.unsupportedFormat
            }
            
            await MainActor.run {
                isProcessing = false
                processingProgress = 1.0
                currentOperation = "Saved successfully"
            }
            
        } catch {
            await MainActor.run {
                isProcessing = false
                processingProgress = 0.0
                currentOperation = "Error: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    /// Конвертирует медиафайл в другой формат
    public func convertMedia(from sourceURL: URL, to destinationURL: URL, targetFormat: MediaFormat) async throws {
        await MainActor.run {
            isProcessing = true
            currentOperation = "Converting to \(targetFormat.rawValue)..."
        }
        
        // Извлекаем кадры из исходного файла
        let frames = try await extractFrames(from: sourceURL)
        
        // Сохраняем в целевой формат
        try await saveFrames(frames, to: destinationURL, format: targetFormat)
    }
    
    // MARK: - Private Methods
    
    private func getFileSize(for url: URL) async throws -> Int64 {
        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(resourceValues.fileSize ?? 0)
    }
    
    private func loadImageInfo(url: URL, format: MediaFormat, fileSize: Int64) async throws -> MediaFileInfo {
        let image = CIImage(contentsOf: url)
        let resolution = image?.extent.size
        // CIImage не имеет alphaInfo, используем альтернативный способ определения alpha
        let hasAlpha = format == .proRes4444 || format == .png || format == .tiff
        
        return MediaFileInfo(
            format: format,
            url: url,
            fileSize: fileSize,
            resolution: resolution,
            hasAlpha: hasAlpha
        )
    }
    
    private func loadVideoInfo(url: URL, format: MediaFormat, fileSize: Int64) async throws -> MediaFileInfo {
        let asset = AVAsset(url: url)
        
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        
        guard let videoTrack = tracks.first else {
            throw MediaProcessingError.noVideoTrack
        }
        
        let frameRate = try await videoTrack.load(.nominalFrameRate)
        let naturalSize = try await videoTrack.load(.naturalSize)
        
        // Определяем битность для ProRes
        var bitDepth: Int? = nil
        if format.isProRes {
            bitDepth = format == .proRes4444 ? 12 : 10
        }
        
        return MediaFileInfo(
            format: format,
            url: url,
            fileSize: fileSize,
            duration: CMTimeGetSeconds(duration),
            frameRate: Double(frameRate),
            resolution: naturalSize,
            bitDepth: bitDepth,
            hasAlpha: format == .proRes4444
        )
    }
    
    private func extractImageFrames(from url: URL, format: MediaFormat, maxFrames: Int) async throws -> [CIImage] {
        guard let image = CIImage(contentsOf: url) else {
            throw MediaProcessingError.failedToLoadImage
        }
        
        // Для статичных изображений возвращаем один кадр
        return [image]
    }
    
    private func extractProResFrames(from url: URL, maxFrames: Int) async throws -> [CIImage] {
        // Используем специализированный ProRes процессор
        return try await proResProcessor.extractFrames(from: url, maxFrames: maxFrames)
    }
    
    private func extractVideoFrames(from url: URL, maxFrames: Int) async throws -> [CIImage] {
        // Используем стандартный видео процессор
        videoProcessor.loadVideo(from: url)
        
        // Ждем загрузки
        while videoProcessor.isLoading {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
        }
        
        // Получаем текущий кадр
        if let currentFrame = videoProcessor.getCurrentFrame() {
            return [currentFrame]
        }
        
        return []
    }
    
    private func saveImageFrames(_ frames: [CIImage], to url: URL, format: MediaFormat) async throws {
        guard let firstFrame = frames.first else {
            throw MediaProcessingError.noFramesToSave
        }
        
        try await imageProcessor.saveImage(firstFrame, to: url, format: format)
    }
    
    private func saveProResFrames(_ frames: [CIImage], to url: URL, format: MediaFormat) async throws {
        try await proResProcessor.saveFrames(frames, to: url, format: format)
    }
    
    private func saveVideoFrames(_ frames: [CIImage], to url: URL, format: MediaFormat) async throws {
        // VideoProcessor не имеет метода saveFrames, используем базовое сохранение
        guard let firstFrame = frames.first else {
            throw MediaProcessingError.noFramesToSave
        }
        
        // Простое сохранение первого кадра как изображения
        // В реальной реализации здесь будет логика сохранения видео
        try await imageProcessor.saveImage(firstFrame, to: url, format: format)
    }
}

// MARK: - Supporting Classes

/// Процессор для изображений
private class ImageProcessor {
    func saveImage(_ image: CIImage, to url: URL, format: MediaFormat) async throws {
        // Реализация сохранения изображений в различных форматах
        // Здесь будет логика для DPX, EXR, TIFF, PNG, JPEG
    }
}

/// Процессор для ProRes (использует существующий код)
private class ProResProcessorWrapper {
    func extractFrames(from url: URL, maxFrames: Int) async throws -> [CIImage] {
        // Используем существующий ProResProcessor из Infrastructure/Video/
        // Здесь будет интеграция с ProResProcessor.swift
        return []
    }
    
    func saveFrames(_ frames: [CIImage], to url: URL, format: MediaFormat) async throws {
        // Используем существующий ProResProcessor для сохранения
    }
}

// MARK: - Errors
public enum MediaProcessingError: Error, LocalizedError {
    case unsupportedFormat
    case unknownFormat
    case noVideoTrack
    case failedToLoadImage
    case noFramesToSave
    case processingTimeout
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Unsupported media format"
        case .unknownFormat:
            return "Unknown media format"
        case .noVideoTrack:
            return "No video track found in file"
        case .failedToLoadImage:
            return "Failed to load image"
        case .noFramesToSave:
            return "No frames to save"
        case .processingTimeout:
            return "Processing timeout"
        }
    }
}
