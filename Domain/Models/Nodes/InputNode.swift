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

// MARK: - Media Types (Legacy - для обратной совместимости)
enum MediaType {
    case image
    case video
    case proRes
}

class InputNode: BaseNode {
    // Universal Media Properties
    @Published var mediaProcessor: UniversalMediaProcessor?
    @Published var mediaFormat: MediaFormat?
    @Published var mediaInfo: MediaFileInfo?
    @Published var currentFrame: CIImage?
    
    // Legacy Properties (для обратной совместимости)
    @Published var nsImage: NSImage?
    @Published var ciImage: CIImage?
    @Published var mediaType: MediaType = .image
    @Published var isVideoLoading: Bool = false
    @Published var videoURL: URL?
    
    // Playback state
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 0.0
    
    // File properties
    @Published var fileName: String?
    @Published var fileSize: String?
    
    // Security-scoped bookmark access
    private var securityScopedURL: URL?
    
    // Performance constants
    private let DEFAULT_PREVIEW_FRAME_INDEX = 0 // Индекс кадра для предварительного просмотра
    private let FRAME_CACHE_LIMIT = 30 // Максимальное количество кадров в кэше
    private let MEDIA_LOAD_TIMEOUT = 30.0 // Таймаут загрузки медиафайла в секундах
    
    // Cache для избежания повторной загрузки
    private var frameCache: [Double: CIImage] = [:]
    private var lastSeekTime: Double = -1.0
    
    init(position: CGPoint) {
        super.init(type: .input, position: position)
    }
    
    // MARK: - Public Methods
    
    /// Определяет тип медиафайла по расширению и содержимому (Legacy)
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
    
    /// Универсальный метод определения формата медиафайла
    func detectMediaFormat(for url: URL) async -> MediaFormat? {
        return await MediaFormatDetector.detectFormat(for: url)
    }
    
    /// Загружает медиафайл с использованием универсальной системы
    @MainActor
    func loadMediaFile(from url: URL) async {
        do {
            // Начинаем безопасный доступ к файлу
            guard url.startAccessingSecurityScopedResource() else {
                print("❌ InputNode: Failed to access security-scoped resource")
                return
            }
            
            defer {
                // Завершаем безопасный доступ
                url.stopAccessingSecurityScopedResource()
            }
            
            // Инициализируем процессор если нужно
            if mediaProcessor == nil {
                mediaProcessor = UniversalMediaProcessor()
            }
            
            // Определяем формат
            mediaFormat = await detectMediaFormat(for: url)
            
            // Обновляем mediaType на основе формата
            if let format = mediaFormat {
                if format.isVideo || format.isProRes {
                    mediaType = .video
                    print("🎬 InputNode: Set mediaType to .video for format: \(format.rawValue)")
                } else {
                    mediaType = .image
                    print("🖼️ InputNode: Set mediaType to .image for format: \(format.rawValue)")
                }
            }
            
            // Загружаем информацию о файле
            mediaInfo = try await mediaProcessor?.loadMedia(from: url)
            
            // Извлекаем первый кадр для предварительного просмотра
            if let frames = try await mediaProcessor?.extractFrames(from: url, maxFrames: 1) {
                currentFrame = frames.first
            }
            
            // Обновляем информацию о файле
            fileName = url.lastPathComponent
            videoURL = url // Сохраняем URL для последующего использования
            
            if let info = mediaInfo {
                fileSize = formatFileSize(info.fileSize)
                duration = info.duration ?? 0.0 // Устанавливаем длительность
                print("🎬 InputNode: Duration set to \(duration)s")
            }
            
            print("🎬 InputNode: Successfully loaded \(mediaFormat?.rawValue ?? "unknown") file")
            
        } catch {
            print("❌ InputNode: Error loading media file: \(error)")
        }
    }
    
    /// Форматирует размер файла для отображения
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
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
                                print("🎬 InputNode: ProRes variant detected")
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
    
    /// Получает строку варианта ProRes по кодеку
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
    
    // MARK: - Legacy Methods (для обратной совместимости)
    
    /// Загружает видео файл (Legacy)
    func loadVideo(from url: URL) async {
        // Используем новую универсальную систему
        await loadMediaFile(from: url)
    }
    
    /// Воспроизводит видео (Legacy)
    func play() {
        isPlaying = true
        print("▶️ InputNode: Play started")
    }
    
    /// Останавливает воспроизведение (Legacy)
    func pause() {
        isPlaying = false
        print("⏸️ InputNode: Pause started")
    }
    
    /// Перематывает к указанному времени (Legacy) - оптимизированная версия
    @MainActor
    func seek(to time: Double) {
        let clampedTime = max(0, min(time, duration))
        
        // Проверяем, не запрашиваем ли мы тот же кадр
        if abs(clampedTime - lastSeekTime) < 0.016 { // Меньше одного кадра при 60fps
            return
        }
        
        currentTime = clampedTime
        lastSeekTime = clampedTime
        print("⏩ InputNode: Seek to \(currentTime)s")
        
        // Проверяем кэш перед загрузкой нового кадра
        if let cachedFrame = frameCache[clampedTime] {
            currentFrame = cachedFrame
            print("🎬 InputNode: Using cached frame at \(clampedTime)s")
        } else {
            // Обновляем текущий кадр только если его нет в кэше
            Task {
                await updateCurrentFrame()
            }
        }
    }
    
    /// Обновляет текущий кадр на основе времени - оптимизированная версия
    @MainActor
    private func updateCurrentFrame() async {
        guard let processor = mediaProcessor,
              let url = videoURL,
              mediaType == .video else { return }
        
        do {
            // Начинаем безопасный доступ к файлу
            guard url.startAccessingSecurityScopedResource() else {
                print("❌ InputNode: Failed to access security-scoped resource for frame update")
                return
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            // Извлекаем кадр для текущего времени
            let frameTime = currentTime
            let frames = try await processor.extractFrames(from: url, maxFrames: 1, startTime: frameTime)
            if let firstFrame = frames.first {
                currentFrame = firstFrame
                
                // Кэшируем кадр
                frameCache[frameTime] = firstFrame
                
                // Ограничиваем размер кэша
                if frameCache.count > FRAME_CACHE_LIMIT {
                    let sortedKeys = frameCache.keys.sorted()
                    let keysToRemove = sortedKeys.prefix(frameCache.count - FRAME_CACHE_LIMIT)
                    for key in keysToRemove {
                        frameCache.removeValue(forKey: key)
                    }
                }
                
                print("🎬 InputNode: Updated frame at \(frameTime)s")
            }
        } catch {
            print("❌ InputNode: Error updating frame: \(error)")
        }
    }
    
    /// Возвращает текущий кадр (Legacy)
    func getCurrentFrame() -> CIImage? {
        return currentFrame
    }
    
    // MARK: - Cleanup
    
    /// Очищает ресурсы
    func cleanup() {
        mediaProcessor = nil
        mediaFormat = nil
        mediaInfo = nil
        currentFrame = nil
        fileName = nil
        fileSize = nil
        frameCache.removeAll()
        print("🧹 InputNode: Cleanup completed")
    }
    
    // MARK: - BaseNode Override
    
    override func process(inputs: [CIImage?]) -> CIImage? {
        // Возвращаем текущий кадр как выход
        return currentFrame
    }
} 
