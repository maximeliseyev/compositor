//
//  VideoProcessor.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 14.07.2025.
//

import AVFoundation
import CoreImage
#if os(macOS)
import AppKit
import CoreVideo
#else
import UIKit
#endif

@MainActor
class VideoProcessor: ObservableObject {
    @Published var isLoading = false
    @Published var currentFrame: CIImage?
    @Published var duration: Double = 0
    @Published var currentTime: Double = 0
    @Published var isPlaying = false
    
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var videoOutput: AVPlayerItemVideoOutput?
    private var asset: AVAsset?
    
#if os(macOS)
    private var displayLink: CVDisplayLink?
    #else
    private var displayLink: CADisplayLink?
    #endif
    
    // Для предпросмотра первого кадра
    private var imageGenerator: AVAssetImageGenerator?
    
    // Кэш для избежания повторной загрузки
    private var loadedURL: URL?
    private var frameCache: [Double: CIImage] = [:]
    private let maxCacheSize = PerformanceConstants.videoFrameCacheSize
    private var lastSeekTime: Double = -1.0
    
    init() {
        setupVideoOutput()
    }
    
    deinit {
        // Очистка ресурсов при деинициализации
        player?.pause()
        // stopDisplayLink() вызывается только из @MainActor контекста
    }
    
    // MARK: - Public Methods
    
    func loadVideo(from url: URL) {
        // Проверяем, не загружаем ли мы тот же файл
        if loadedURL == url && player != nil {
            print("🎬 VideoProcessor: Video already loaded, skipping reload")
            return
        }
        
        isLoading = true
        print("🎬 VideoProcessor.loadVideo url=\(url.lastPathComponent)")
        
        // Очищаем предыдущий кэш
        frameCache.removeAll()
        loadedURL = url
        
        // Создаем AVAsset из URL
        asset = AVAsset(url: url)
        
        guard let asset = asset else {
            isLoading = false
            return
        }
        
        // Проверяем, что это видео
        Task {
            do {
                let tracks = try await asset.loadTracks(withMediaType: .video)
                guard !tracks.isEmpty else {
                    print("⚠️ No video tracks found")
                    isLoading = false
                    return
                }
                
                // Получаем длительность
                let duration = try await asset.load(.duration)
                self.duration = CMTimeGetSeconds(duration)
                print("⏱️ Video duration set: \(self.duration)")
                
                // Создаем player item
                let playerItem = AVPlayerItem(asset: asset)
                self.playerItem = playerItem
                
                // Создаем player
                let player = AVPlayer(playerItem: playerItem)
                self.player = player
                
                // Настраиваем video output
                setupVideoOutput()
                print("🔌 Video output attached: \(self.videoOutput != nil)")
                
                // Загружаем первый кадр
                await loadFirstFrame()
                
                isLoading = false
                print("✅ VideoProcessor finished loading")
                
            } catch {
                print("❌ VideoProcessor load error: \(error)")
                isLoading = false
            }
        }
    }
    
    func play() {
        guard let player = player else { return }
        
        player.play()
        isPlaying = true
        startDisplayLink()
    }
    
    func pause() {
        guard let player = player else { return }
        
        player.pause()
        isPlaying = false
        stopDisplayLink()
    }
    
    func seek(to time: Double) {
        guard let player = player else { return }
        
        let clampedTime = max(0, min(time, duration))
        
        // Проверяем, не запрашиваем ли мы тот же кадр
        if abs(clampedTime - lastSeekTime) < 0.016 { // Меньше одного кадра при 60fps
            return
        }
        
        lastSeekTime = clampedTime
        currentTime = clampedTime
        
        // Проверяем кэш перед загрузкой нового кадра
        if let cachedFrame = frameCache[clampedTime] {
            currentFrame = cachedFrame
            print("🎬 VideoProcessor: Using cached frame at \(clampedTime)s")
        } else {
            let cmTime = CMTime(seconds: clampedTime, preferredTimescale: 600)
            player.seek(to: cmTime) { [weak self] _ in
                Task { @MainActor in
                    self?.updateFrame()
                }
            }
        }
    }
    
    func getCurrentFrame() -> CIImage? {
        return currentFrame
    }
    
    // MARK: - Private Methods
    
    private func setupVideoOutput() {
        guard let playerItem = playerItem else { return }
        
        let settings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        
        videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: settings)
        guard let videoOutput = videoOutput else { return }
        
        playerItem.add(videoOutput)
    }
    
    private func loadFirstFrame() async {
        guard let asset = asset else { return }
        
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.requestedTimeToleranceBefore = .zero
        
        self.imageGenerator = imageGenerator
        
        let time = CMTime(seconds: 0, preferredTimescale: 600)
        
        do {
            let cgImage = try await imageGenerator.image(at: time).image
            let ciImage = CIImage(cgImage: cgImage)
            
            currentFrame = ciImage
            frameCache[0.0] = ciImage
            print("🖼️ First frame generated: extent=\(ciImage.extent)")
        } catch {
            print("❌ Error loading first frame: \(error)")
        }
    }
    
#if os(macOS)
    private func startDisplayLink() {
        stopDisplayLink()
        
        var displayLink: CVDisplayLink?
        let displayLinkCallback: CVDisplayLinkOutputCallback = { (displayLink, inNow, inOutputTime, flagsIn, flagsOut, displayLinkContext) in
            let processor = Unmanaged<VideoProcessor>.fromOpaque(displayLinkContext!).takeUnretainedValue()
            Task { @MainActor in
                processor.updateFrame()
            }
            return kCVReturnSuccess
        }
        
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        
        if let displayLink = displayLink {
            CVDisplayLinkSetOutputCallback(displayLink, displayLinkCallback, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
            CVDisplayLinkStart(displayLink)
            self.displayLink = displayLink
        }
    }
    
    private func stopDisplayLink() {
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
            self.displayLink = nil
        }
    }
    
    private func updateFrame() {
        guard let videoOutput = videoOutput,
              let playerItem = playerItem else { return }
        
        let currentTime = CMTimeGetSeconds(playerItem.currentTime())
        self.currentTime = currentTime
        
        let itemTime = videoOutput.itemTime(forHostTime: CACurrentMediaTime())
        
        if videoOutput.hasNewPixelBuffer(forItemTime: itemTime) {
            if let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil) {
                let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                currentFrame = ciImage
                
                // Кэшируем кадр
                frameCache[currentTime] = ciImage
                
                // Ограничиваем размер кэша
                if frameCache.count > maxCacheSize {
                    let sortedKeys = frameCache.keys.sorted()
                    let keysToRemove = sortedKeys.prefix(frameCache.count - maxCacheSize)
                    for key in keysToRemove {
                        frameCache.removeValue(forKey: key)
                    }
                }
            }
        }
    }
#else
    private func startDisplayLink() {
        stopDisplayLink()
        
        displayLink = CADisplayLink(target: self, selector: #selector(updateFrame))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func updateFrame() {
        guard let videoOutput = videoOutput,
              let playerItem = playerItem else { return }
        
        let currentTime = CMTimeGetSeconds(playerItem.currentTime())
        self.currentTime = currentTime
        
        let itemTime = videoOutput.itemTime(forHostTime: CACurrentMediaTime())
        
        if videoOutput.hasNewPixelBuffer(forItemTime: itemTime) {
            if let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil) {
                let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                currentFrame = ciImage
                
                // Кэшируем кадр
                frameCache[currentTime] = ciImage
                
                // Ограничиваем размер кэша
                if frameCache.count > maxCacheSize {
                    let sortedKeys = frameCache.keys.sorted()
                    let keysToRemove = sortedKeys.prefix(frameCache.count - maxCacheSize)
                    for key in keysToRemove {
                        frameCache.removeValue(forKey: key)
                    }
                }
            }
        }
    }
#endif
} 
