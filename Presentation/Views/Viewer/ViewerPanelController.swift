//
//  ViewerPanelController.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 14.07.2025.
//

import SwiftUI
import Combine
import CoreImage

class ViewerPanelController: ObservableObject {
    // MARK: - Image Properties
    @Published var currentImage: NSImage?
    
    // MARK: - Video Properties
    @Published var isVideoMode: Bool = false
    @Published var isPlaying: Bool = false
    @Published var videoDuration: Double = 0
    @Published var currentTime: Double = 0
    @Published var playbackSpeed: Double = 1.0
    @Published var isLooping: Bool = false
    @Published var isReversing: Bool = false
    
    // MARK: - UI Properties
    @Published var zoomLevel: Double = 1.0
    @Published var showTransportOverlay: Bool = true
    
    // MARK: - Scrubbing state
    @Published var isScrubbing: Bool = false
    
    // MARK: - Private properties
    private var overlayTimer: Timer?
    private var playbackTimer: Timer?
    private var connectedInputNode: InputNode?
    private var cancellables = Set<AnyCancellable>()
    
    // Performance/behavior constants
    private let DEFAULT_FRAME_RATE: Double = 30.0 // Default frames-per-second used when frame rate is unknown
    
    init() {
        setupOverlayTimer()
    }
    
    // MARK: - Image Management
    
    func updateImage(_ image: NSImage?) {
        currentImage = image
        
        // Reset zoom when new image is loaded
        if image != nil {
            zoomToFit()
        }
    }
    
    func updateFromInputNode(_ inputNode: InputNode) {
        print("🔗 updateFromInputNode called")
        connectedInputNode = inputNode
        
        // Setup observation of input node
        setupInputNodeObservation(inputNode)
        
        // Update current state
        isVideoMode = inputNode.mediaType == .video
        print("📺 isVideoMode set to: \(isVideoMode) (mediaType: \(inputNode.mediaType))")
        
        if isVideoMode {
            videoDuration = inputNode.duration
            currentTime = inputNode.currentTime
            isPlaying = inputNode.isPlaying
            print("🎥 Viewer bound to InputNode (video). duration=\(videoDuration), currentTime=\(currentTime), playing=\(isPlaying)")
        } else {
            videoDuration = 0
            currentTime = 0
            isPlaying = false
            print("🖼️ Viewer bound to InputNode (image)")
        }
    }
    
    // MARK: - Video Control Methods
    
    func togglePlayback() {
        print("🎮 togglePlayback called - isVideoMode: \(isVideoMode), connectedInputNode: \(connectedInputNode != nil)")
        guard let inputNode = connectedInputNode, isVideoMode else { 
            print("❌ togglePlayback blocked - no inputNode or not video mode")
            return 
        }
        
        if isPlaying {
            print("⏸️ Pausing playback")
            inputNode.pause()
            isPlaying = false
            stopPlaybackTimer()
        } else {
            print("▶️ Starting playback")
            inputNode.play()
            isPlaying = true
            startPlaybackTimer()
        }
        
        showTransportOverlayTemporarily()
    }
    
    func toggleReversePlayback() {
        guard connectedInputNode != nil, isVideoMode else { return }
        
        isReversing.toggle()
        // If not currently playing, start playback in the chosen direction
        if isPlaying == false {
            isPlaying = true
        }
        
        // Restart timer to apply the new direction
        stopPlaybackTimer()
        startPlaybackTimer()
        
        showTransportOverlayTemporarily()
    }
    
    @MainActor
    func stepBackward() {
        print("⏪ stepBackward called")
        guard let inputNode = connectedInputNode, isVideoMode else { 
            print("❌ stepBackward blocked")
            return 
        }
        
        let newTime = max(0, currentTime - (1.0/30.0)) // Step back one frame at 30fps
        print("⏪ Seeking to: \(newTime)")
        inputNode.seek(to: newTime)
        showTransportOverlayTemporarily()
    }
    
    @MainActor
    func stepForward() {
        print("⏩ stepForward called")
        guard let inputNode = connectedInputNode, isVideoMode else { 
            print("❌ stepForward blocked")
            return 
        }
        
        let newTime = min(videoDuration, currentTime + (1.0/30.0)) // Step forward one frame at 30fps
        print("⏩ Seeking to: \(newTime)")
        inputNode.seek(to: newTime)
        showTransportOverlayTemporarily()
    }
    
    @MainActor
    func jumpBackward() {
        guard let inputNode = connectedInputNode, isVideoMode else { return }
        
        let newTime = max(0, currentTime - 10.0) // Jump back 10 seconds
        inputNode.seek(to: newTime)
        showTransportOverlayTemporarily()
    }
    
    @MainActor
    func jumpForward() {
        guard let inputNode = connectedInputNode, isVideoMode else { return }
        
        let newTime = min(videoDuration, currentTime + 10.0) // Jump forward 10 seconds
        inputNode.seek(to: newTime)
        showTransportOverlayTemporarily()
    }
    
    func setPlaybackSpeed(_ speed: Double) {
        playbackSpeed = speed
        // Note: Actual playback speed control would need to be implemented in VideoProcessor
        showTransportOverlayTemporarily()
        
        // Restart timer with updated speed if currently playing
        if isPlaying {
            stopPlaybackTimer()
            startPlaybackTimer()
        }
    }
    
    func toggleLoop() {
        isLooping.toggle()
        // Note: Loop functionality would need to be implemented in VideoProcessor
        showTransportOverlayTemporarily()
    }
    
    // MARK: - Scrubbing Methods
    
    func beginScrubbing() {
        isScrubbing = true
        showTransportOverlay = true
    }
    
    @MainActor
    func scrub(to time: Double) {
        guard let inputNode = connectedInputNode, isVideoMode else { return }
        
        currentTime = time
        inputNode.seek(to: time)
    }
    
    func endScrubbing() {
        isScrubbing = false
        showTransportOverlayTemporarily()
    }
    
    // MARK: - Zoom Methods
    
    func zoomToFit() {
        zoomLevel = 1.0 // This would be calculated based on image size vs viewer size
    }
    
    func zoomToActual() {
        zoomLevel = 1.0 // 100% actual size
    }
    
    func zoomIn() {
        zoomLevel = min(zoomLevel * 1.25, 10.0)
    }
    
    func zoomOut() {
        zoomLevel = max(zoomLevel / 1.25, 0.1)
    }
    
    // MARK: - Private Methods
    
    private func setupInputNodeObservation(_ inputNode: InputNode) {
        // Clear previous subscriptions
        cancellables.removeAll()
        
        // Observe media type changes
        inputNode.$mediaType
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mediaType in
                print("🔄 mediaType changed to: \(mediaType)")
                self?.isVideoMode = (mediaType == .video)
                print("📺 isVideoMode updated to: \(self?.isVideoMode ?? false)")
                if mediaType != .video {
                    self?.isPlaying = false
                    self?.videoDuration = 0
                    self?.currentTime = 0
                }
                print("🔄 mediaType=\(mediaType == .video ? "video" : "image")")
            }
            .store(in: &cancellables)
        
        // Observe current frame changes
        inputNode.$currentFrame
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ciImage in
                if let ciImage = ciImage {
                    print("🧩 Received frame: extent=\(ciImage.extent)")
                    self?.updateImage(Self.nsImage(from: ciImage))
                }
            }
            .store(in: &cancellables)
        
        // Observe image changes
        inputNode.$nsImage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] image in
                if inputNode.mediaType == .image {
                    print("🖼️ nsImage updated: \(image != nil)")
                    self?.updateImage(image)
                }
            }
            .store(in: &cancellables)
        
        // Observe CIImage for images where only CIImage is set
        inputNode.$ciImage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ciImage in
                if inputNode.mediaType == .image, let ciImage = ciImage {
                    print("🧩 CIImage updated: extent=\(ciImage.extent)")
                    self?.updateImage(Self.nsImage(from: ciImage))
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Helpers
    private static func nsImage(from ciImage: CIImage) -> NSImage {
        let rep = NSCIImageRep(ciImage: ciImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }
    
    private func setupOverlayTimer() {
        // Auto-hide transport overlay after 3 seconds of inactivity
        overlayTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                if self?.isScrubbing != true && self?.isPlaying != true {
                    self?.showTransportOverlay = false
                }
            }
        }
    }
    
    private func showTransportOverlayTemporarily() {
        showTransportOverlay = true
        
        // Reset the timer
        overlayTimer?.invalidate()
        overlayTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                if self?.isScrubbing != true {
                    self?.showTransportOverlay = false
                }
            }
        }
    }
    
    private func startPlaybackTimer() {
        guard isVideoMode, videoDuration > 0 else { return }
        stopPlaybackTimer()
        
        // Determine frame interval. Use default until we surface actual frame rate from input node.
        let fps = max(1.0, DEFAULT_FRAME_RATE * max(0.1, playbackSpeed))
        let interval = 1.0 / fps
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self, let inputNode = self.connectedInputNode else { return }
            
            let delta = 1.0 / self.DEFAULT_FRAME_RATE
            let signedDelta = self.isReversing ? -delta : delta
            var newTime = self.currentTime + signedDelta
            
            if self.isLooping {
                if newTime < 0 { newTime = self.videoDuration }
                if newTime > self.videoDuration { newTime = 0 }
            } else {
                newTime = min(max(0, newTime), self.videoDuration)
            }
            
            self.currentTime = newTime
            inputNode.seek(to: newTime)
        }
    }
    
    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
}
