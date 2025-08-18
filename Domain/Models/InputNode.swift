//
//  InputNode.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 14.07.2025.
//

import SwiftUI
import CoreImage
import AVFoundation
import UniformTypeIdentifiers

// MARK: - Media Types
enum MediaType {
    case image
    case video
    case proRes // Новый тип для ProRes файлов
}

class InputNode: BaseNode {
    // Image properties
    @Published var nsImage: NSImage?
    @Published var ciImage: CIImage?
    
    // Video properties
    @Published var videoProcessor: VideoProcessor?
    @Published var mediaType: MediaType = .image
    @Published var isVideoLoading: Bool = false
    @Published var videoURL: URL?
    
    // ProRes properties
    @Published var isProResProcessing: Bool = false
    @Published var proResFrames: [CIImage] = []
    @Published var currentProResFrameIndex: Int = 0
    @Published var proResFrameRate: Double = 30.0
    @Published var proResVariant: String?
    
    // File properties
    @Published var fileName: String?
    @Published var fileSize: String?
    
    // Security-scoped bookmark access
    private var securityScopedURL: URL?
    
    // Performance constants
    private let PRORES_FRAME_BUFFER_SIZE = 30 // Количество кадров для буферизации
    private let PRORES_SEEK_THRESHOLD = 0.1 // Порог для определения необходимости перемотки (в секундах)
    
    init(position: CGPoint) {
        super.init(type: .input, position: position)
    }
    
    // MARK: - Public Methods
    
    /// Определяет тип медиафайла по расширению и содержимому
    func getMediaType(for url: URL) -> MediaType {
        let pathExtension = url.pathExtension.lowercased()
        let videoExtensions = ["mov", "mp4", "m4v", "avi", "mkv", "webm", "3gp", "3g2", "asf", "wmv", "flv", "f4v", "ts", "m2ts", "mts"]
        
        // Проверяем, является ли это ProRes файлом
        if isProResFile(url) {
            print("🎬 InputNode: Detected ProRes file - \(url.lastPathComponent)")
            return .proRes
        }
        
        return videoExtensions.contains(pathExtension) ? .video : .image
    }
    
    /// Проверяет, является ли файл ProRes
    private func isProResFile(_ url: URL) -> Bool {
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
                                    self.proResVariant = getProResVariantString(from: codecType)
                                    print("🎬 InputNode: ProRes variant detected - \(self.proResVariant ?? "Unknown")")
                                }
                            }
                        }
                    }
                } catch {
                    print("⚠️ InputNode: Error checking ProRes codec: \(error)")
                }
            }
            
            return true
        }
        
        return false
    }
    
    /// Определяет вариант ProRes по кодеку
    private func getProResVariantString(from codecType: FourCharCode) -> String {
        switch codecType {
        case 0x61703434: return "ProRes 4444" // 'ap44'
        case 0x61706871: return "ProRes 422 HQ" // 'aphq'
        case 0x61703232: return "ProRes 422" // 'ap22'
        case 0x61706c74: return "ProRes 422 LT" // 'aplt'
        case 0x61707078: return "ProRes 422 Proxy" // 'appx'
        default: return "ProRes 422 HQ"
        }
    }
    
    /// Универсальный метод загрузки медиафайла
    func loadMedia(from url: URL) {
        beginSecurityScopedAccess(for: url)
        let detectedType = getMediaType(for: url)
        mediaType = detectedType
        
        // Сохраняем информацию о файле
        fileName = url.lastPathComponent
        updateFileSize(for: url)
        
        switch detectedType {
        case .image:
            loadImage(from: url)
        case .video:
            loadVideo(from: url)
        case .proRes:
            loadProRes(from: url)
        }
    }
    
    /// Загрузка изображения (существующий метод)
    func loadImage(from url: URL) {
        // Очищаем видео и ProRes если загружали их ранее
        cleanupVideo()
        cleanupProRes()
        
        if let nsImage = NSImage(contentsOf: url) {
            self.nsImage = nsImage
            if let tiffData = nsImage.tiffRepresentation, let ciImage = CIImage(data: tiffData) {
                self.ciImage = ciImage
            } else {
                self.ciImage = nil
            }
        } else {
            self.nsImage = nil
            self.ciImage = nil
        }
    }
    
    /// Загрузка видео через VideoProcessor
    func loadVideo(from url: URL) {
        // Очищаем изображение и ProRes если загружали их ранее
        cleanupImage()
        cleanupProRes()
        
        isVideoLoading = true
        videoURL = url
        
        // Создаем новый VideoProcessor если его нет
        if videoProcessor == nil {
            videoProcessor = VideoProcessor()
        } else {
            // Пересоздадим, чтобы гарантировать чистое состояние подписок и AVPlayerItem
            videoProcessor?.pause()
            videoProcessor = VideoProcessor()
        }
        
        // Загружаем видео
        videoProcessor?.loadVideo(from: url)
        print("📥 InputNode.loadVideo: \(url.lastPathComponent)")
        
        // Отслеживаем состояние загрузки
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isVideoLoading = self.videoProcessor?.isLoading ?? false
        }
    }
    
    /// Загрузка ProRes файла через специализированный процессор
    func loadProRes(from url: URL) {
        // Очищаем изображение и видео если загружали их ранее
        cleanupImage()
        cleanupVideo()
        
        isProResProcessing = true
        videoURL = url
        
        print("🎬 InputNode.loadProRes: \(url.lastPathComponent)")
        
        // Временно обрабатываем ProRes как обычное видео
        // TODO: Интегрировать ProResProcessor после исправления зависимостей
        mediaType = .video // Временно меняем тип на video для совместимости
        loadVideo(from: url)
        isProResProcessing = false
    }
    
    // MARK: - Video Control Methods
    
    func playVideo() {
        switch mediaType {
        case .video:
            videoProcessor?.play()
        case .proRes:
            // Временно используем video processor для ProRes
            if videoProcessor != nil {
                videoProcessor?.play()
            } else {
                startProResPlayback()
            }
        case .image:
            break
        }
    }
    
    func pauseVideo() {
        switch mediaType {
        case .video:
            videoProcessor?.pause()
        case .proRes:
            // Временно используем video processor для ProRes
            if videoProcessor != nil {
                videoProcessor?.pause()
            } else {
                stopProResPlayback()
            }
        case .image:
            break
        }
    }
    
    func seekVideo(to time: Double) {
        switch mediaType {
        case .video:
            videoProcessor?.seek(to: time)
        case .proRes:
            // Временно используем video processor для ProRes
            if videoProcessor != nil {
                videoProcessor?.seek(to: time)
            } else {
                seekProRes(to: time)
            }
        case .image:
            break
        }
    }
    
    var isVideoPlaying: Bool {
        switch mediaType {
        case .video:
            return videoProcessor?.isPlaying ?? false
        case .proRes:
            // Временно используем video processor для ProRes
            if videoProcessor != nil {
                return videoProcessor?.isPlaying ?? false
            } else {
                return isProResPlaying
            }
        case .image:
            return false
        }
    }
    
    var videoDuration: Double {
        switch mediaType {
        case .video:
            return videoProcessor?.duration ?? 0
        case .proRes:
            // Временно используем video processor для ProRes
            if videoProcessor != nil {
                return videoProcessor?.duration ?? 0
            } else {
                return Double(proResFrames.count) / proResFrameRate
            }
        case .image:
            return 0
        }
    }
    
    var videoCurrentTime: Double {
        switch mediaType {
        case .video:
            return videoProcessor?.currentTime ?? 0
        case .proRes:
            // Временно используем video processor для ProRes
            if videoProcessor != nil {
                return videoProcessor?.currentTime ?? 0
            } else {
                return Double(currentProResFrameIndex) / proResFrameRate
            }
        case .image:
            return 0
        }
    }
    
    // MARK: - ProRes Playback Methods
    
    private var isProResPlaying: Bool = false
    private var proResPlaybackTimer: Timer?
    
    private func startProResPlayback() {
        guard !proResFrames.isEmpty else { return }
        
        isProResPlaying = true
        let frameInterval = 1.0 / proResFrameRate
        
        proResPlaybackTimer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { [weak self] _ in
            self?.advanceProResFrame()
        }
        
        print("▶️ ProRes playback started at \(proResFrameRate) fps")
    }
    
    private func stopProResPlayback() {
        isProResPlaying = false
        proResPlaybackTimer?.invalidate()
        proResPlaybackTimer = nil
        print("⏸️ ProRes playback stopped")
    }
    
    private func advanceProResFrame() {
        guard !proResFrames.isEmpty else { return }
        
        currentProResFrameIndex = (currentProResFrameIndex + 1) % proResFrames.count
        
        // Если достигли конца, останавливаем воспроизведение
        if currentProResFrameIndex == 0 {
            stopProResPlayback()
        }
    }
    
    private func seekProRes(to time: Double) {
        guard !proResFrames.isEmpty else { return }
        
        let targetFrameIndex = Int(time * proResFrameRate)
        currentProResFrameIndex = max(0, min(targetFrameIndex, proResFrames.count - 1))
        
        print("⏩ ProRes seek to frame \(currentProResFrameIndex) at time \(time)s")
    }
    
    // MARK: - Processing Override
    
    override func process(inputs: [CIImage?]) -> CIImage? {
        switch mediaType {
        case .image:
            return ciImage
        case .video:
            return videoProcessor?.getCurrentFrame()
        case .proRes:
            // Временно используем video processor для ProRes
            if videoProcessor != nil {
                return videoProcessor?.getCurrentFrame()
            } else {
                guard !proResFrames.isEmpty && currentProResFrameIndex < proResFrames.count else {
                    return nil
                }
                return proResFrames[currentProResFrameIndex]
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func cleanupImage() {
        nsImage = nil
        ciImage = nil
    }
    
    private func cleanupVideo() {
        videoProcessor?.pause()
        videoProcessor = nil
        videoURL = nil
    }
    
    private func cleanupProRes() {
        stopProResPlayback()
        proResFrames.removeAll()
        currentProResFrameIndex = 0
        proResVariant = nil
        videoURL = nil
    }
    
    private func updateFileSize(for url: URL) {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                self.fileSize = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            }
        } catch {
            self.fileSize = nil
        }
    }
    
    // MARK: - Node Properties Override
    
    override var title: String {
        if let fileName = fileName {
            return fileName
        }
        return "Input"
    }
    
    // MARK: - File Type Checking
    
    static func getSupportedFileTypes() -> [UTType] {
        return [
            // Video formats
            .movie, .video, .quickTimeMovie, .mpeg4Movie,
            // Image formats  
            .image, .png, .jpeg, .tiff, .gif, .bmp, .heic, .webP
        ]
    }
    
    static func isVideoFile(url: URL) -> Bool {
        let pathExtension = url.pathExtension.lowercased()
        let videoExtensions = ["mov", "mp4", "m4v", "avi", "mkv", "webm", "3gp", "3g2", "asf", "wmv", "flv", "f4v", "ts", "m2ts", "mts"]
        return videoExtensions.contains(pathExtension)
    }
    
    static func isImageFile(url: URL) -> Bool {
        let pathExtension = url.pathExtension.lowercased()  
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "heic", "webp"]
        return imageExtensions.contains(pathExtension)
    }
    
    // MARK: - Security Scoped Access Helpers
    private func beginSecurityScopedAccess(for url: URL) {
        // Close previous access if any
        endSecurityScopedAccess()
        if url.startAccessingSecurityScopedResource() {
            securityScopedURL = url
            print("🔐 Started security-scoped access for: \(url.path)")
        } else {
            print("❗ Failed to start security-scoped access for: \(url.path)")
        }
    }
    
    private func endSecurityScopedAccess() {
        if let u = securityScopedURL {
            u.stopAccessingSecurityScopedResource()
            print("🔓 Stopped security-scoped access for: \(u.path)")
            securityScopedURL = nil
        }
    }
} 
