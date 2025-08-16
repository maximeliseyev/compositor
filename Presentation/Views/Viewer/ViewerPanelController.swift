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
    
    // MARK: - UI Properties
    @Published var zoomLevel: Double = 1.0
    @Published var showTransportOverlay: Bool = true
    
    // MARK: - Scrubbing state
    @Published var isScrubbing: Bool = false
    
    // MARK: - Private properties
    private var overlayTimer: Timer?
    private var connectedInputNode: InputNode?
    private var cancellables = Set<AnyCancellable>()
    
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
        connectedInputNode = inputNode
        
        // Setup observation of input node
        setupInputNodeObservation(inputNode)
        
        // Update current state
        isVideoMode = inputNode.mediaType == .video
        
        if isVideoMode {
            videoDuration = inputNode.videoDuration
            currentTime = inputNode.videoCurrentTime
            isPlaying = inputNode.isVideoPlaying
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
        guard let inputNode = connectedInputNode, isVideoMode else { return }
        
        if isPlaying {
            inputNode.pauseVideo()
        } else {
            inputNode.playVideo()
        }
        
        showTransportOverlayTemporarily()
    }
    
    func stepBackward() {
        guard let inputNode = connectedInputNode, isVideoMode else { return }
        
        let newTime = max(0, currentTime - (1.0/30.0)) // Step back one frame at 30fps
        inputNode.seekVideo(to: newTime)
        showTransportOverlayTemporarily()
    }
    
    func stepForward() {
        guard let inputNode = connectedInputNode, isVideoMode else { return }
        
        let newTime = min(videoDuration, currentTime + (1.0/30.0)) // Step forward one frame at 30fps
        inputNode.seekVideo(to: newTime)
        showTransportOverlayTemporarily()
    }
    
    func jumpBackward() {
        guard let inputNode = connectedInputNode, isVideoMode else { return }
        
        let newTime = max(0, currentTime - 10.0) // Jump back 10 seconds
        inputNode.seekVideo(to: newTime)
        showTransportOverlayTemporarily()
    }
    
    func jumpForward() {
        guard let inputNode = connectedInputNode, isVideoMode else { return }
        
        let newTime = min(videoDuration, currentTime + 10.0) // Jump forward 10 seconds
        inputNode.seekVideo(to: newTime)
        showTransportOverlayTemporarily()
    }
    
    func setPlaybackSpeed(_ speed: Double) {
        playbackSpeed = speed
        // Note: Actual playback speed control would need to be implemented in VideoProcessor
        showTransportOverlayTemporarily()
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
    
    func scrub(to time: Double) {
        guard let inputNode = connectedInputNode, isVideoMode else { return }
        
        currentTime = time
        inputNode.seekVideo(to: time)
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
        
        // Re-bind when videoProcessor appears/changes
        inputNode.$videoProcessor
            .receive(on: DispatchQueue.main)
            .sink { [weak self] processor in
                self?.bindVideoProcessor(processor)
            }
            .store(in: &cancellables)
        
        // Bind immediately if already available
        bindVideoProcessor(inputNode.videoProcessor)
        
        // Observe media type changes
        inputNode.$mediaType
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mediaType in
                self?.isVideoMode = (mediaType == .video)
                if mediaType != .video {
                    self?.isPlaying = false
                    self?.videoDuration = 0
                    self?.currentTime = 0
                }
                print("🔄 mediaType=\(mediaType == .video ? "video" : "image")")
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
    
    private func bindVideoProcessor(_ videoProcessor: VideoProcessor?) {
        guard let videoProcessor = videoProcessor else { return }
        print("👀 Subscribing to VideoProcessor events")
        
        videoProcessor.$currentFrame
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ciImage in
                guard let ciImage = ciImage else { return }
                print("🧩 Received video frame: extent=\(ciImage.extent)")
                self?.updateImage(Self.nsImage(from: ciImage))
            }
            .store(in: &cancellables)
        
        videoProcessor.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                print("▶️ isPlaying=\(isPlaying)")
                self?.isPlaying = isPlaying
            }
            .store(in: &cancellables)
        
        videoProcessor.$duration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                print("⏱️ duration=\(duration)")
                self?.videoDuration = duration
            }
            .store(in: &cancellables)
        
        videoProcessor.$currentTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] currentTime in
                if self?.isScrubbing != true {
                    print("⏳ currentTime=\(currentTime)")
                    self?.currentTime = currentTime
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
}
