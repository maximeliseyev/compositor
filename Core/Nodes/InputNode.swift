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
    
    // File properties
    @Published var fileName: String?
    @Published var fileSize: String?
    
    init(position: CGPoint) {
        super.init(type: .input, position: position)
    }
    
    // MARK: - Public Methods
    
    /// Определяет тип медиафайла по расширению
    func getMediaType(for url: URL) -> MediaType {
        let pathExtension = url.pathExtension.lowercased()
        let videoExtensions = ["mov", "mp4", "m4v", "avi", "mkv", "webm", "3gp", "3g2", "asf", "wmv", "flv", "f4v", "ts", "m2ts", "mts"]
        
        return videoExtensions.contains(pathExtension) ? .video : .image
    }
    
    /// Универсальный метод загрузки медиафайла
    func loadMedia(from url: URL) {
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
        }
    }
    
    /// Загрузка изображения (существующий метод)
    func loadImage(from url: URL) {
        // Очищаем видео если загружали его ранее
        cleanupVideo()
        
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
        // Очищаем изображение если загружали его ранее
        cleanupImage()
        
        isVideoLoading = true
        videoURL = url
        
        // Создаем новый VideoProcessor если его нет
        if videoProcessor == nil {
            videoProcessor = VideoProcessor()
        }
        
        // Загружаем видео
        videoProcessor?.loadVideo(from: url)
        
        // Отслеживаем состояние загрузки
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isVideoLoading = self.videoProcessor?.isLoading ?? false
        }
    }
    
    // MARK: - Video Control Methods
    
    func playVideo() {
        videoProcessor?.play()
    }
    
    func pauseVideo() {
        videoProcessor?.pause()
    }
    
    func seekVideo(to time: Double) {
        videoProcessor?.seek(to: time)
    }
    
    var isVideoPlaying: Bool {
        return videoProcessor?.isPlaying ?? false
    }
    
    var videoDuration: Double {
        return videoProcessor?.duration ?? 0
    }
    
    var videoCurrentTime: Double {
        return videoProcessor?.currentTime ?? 0
    }
    
    // MARK: - Processing Override
    
    override func process(inputs: [CIImage?]) -> CIImage? {
        switch mediaType {
        case .image:
            return ciImage
        case .video:
            return videoProcessor?.getCurrentFrame()
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
} 
