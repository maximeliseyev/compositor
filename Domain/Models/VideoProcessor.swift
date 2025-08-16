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
    
    init() {
        setupVideoOutput()
    }
    
    deinit {
        stopDisplayLink()
        player?.pause()
    }
    
    // MARK: - Public Methods
    
    func loadVideo(from url: URL) {
        isLoading = true
        print("🎬 VideoProcessor.loadVideo url=\(url.lastPathComponent)")
        
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
                    await MainActor.run {
                        print("⚠️ No video tracks found")
                        isLoading = false
                    }
                    return
                }
                
                // Получаем длительность
                let duration = try await asset.load(.duration)
                await MainActor.run {
                    self.duration = CMTimeGetSeconds(duration)
                    print("⏱️ Video duration set: \(self.duration)")
                }
                
                // Создаем player item
                let playerItem = await AVPlayerItem(asset: asset)
                self.playerItem = playerItem
                
                // Создаем player
                let player = AVPlayer(playerItem: playerItem)
                self.player = player
                
                // Настраиваем video output
                setupVideoOutput()
                print("🔌 Video output attached: \(self.videoOutput != nil)")
                
                // Загружаем первый кадр
                await loadFirstFrame()
                
                await MainActor.run {
                    self.isLoading = false
                    print("✅ VideoProcessor finished loading")
                }
                
            } catch {
                await MainActor.run {
                    print("❌ VideoProcessor load error: \(error)")
                    self.isLoading = false
                }
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
        
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime) { [weak self] _ in
            self?.updateCurrentFrame()
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
            
            await MainActor.run {
                self.currentFrame = ciImage
                print("🖼️ First frame generated: extent=\(ciImage.extent)")
            }
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
            processor.updateFrame()
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
        updateCurrentFrame()
        updateCurrentTime()
    }
    
    #endif
    
    #if os(macOS)
        private func updateFrame() {
            DispatchQueue.main.async {
                self.updateCurrentFrame()
                self.updateCurrentTime()
            }
        }
        #endif
    
    private func updateCurrentFrame() {
        guard let videoOutput = videoOutput,
              let playerItem = playerItem else { return }
        
        let currentTime = playerItem.currentTime()
        
        if videoOutput.hasNewPixelBuffer(forItemTime: currentTime) {
            let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: currentTime, itemTimeForDisplay: nil)
            
            if let pixelBuffer = pixelBuffer {
                let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                
                DispatchQueue.main.async {
                    self.currentFrame = ciImage
                    print("🧩 New frame from videoOutput: extent=\(ciImage.extent)")
                }
            }
        } else {
            // Polling without a new pixel buffer
            // print("(debug) No new pixel buffer at time: \(CMTimeGetSeconds(currentTime))")
        }
    }
    
    private func updateCurrentTime() {
        guard let player = player else { return }
        
        let time = CMTimeGetSeconds(player.currentTime())
        
        DispatchQueue.main.async {
            self.currentTime = time
        }
    }
} 
