//
//  ViewerPanel.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 14.07.2025.
//

import SwiftUI

struct ViewerPanel: View {
    @ObservedObject var controller: ViewerPanelController
    
    var body: some View {
        VStack(spacing: 0) {
            // Main viewer area
        ZStack {
                // Background
            Rectangle()
                .fill(Color.black)
            
            if let image = controller.currentImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                    // Empty state
                VStack(spacing: 16) {
                        Image(systemName: "tv")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                    Text("Viewer")
                        .font(.title2)
                        .foregroundColor(.gray)
                        
                        Text("Connect an Input or View node to see content")
                        .font(.caption)
                        .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                // Overlay controls
                ViewerOverlayControls(controller: controller)
            }
            .clipped()
            
            // Timeline and transport controls
            ViewerTransportControls(controller: controller)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .border(Color.gray.opacity(0.3), width: 1)
    }
}

// MARK: - Viewer Overlay Controls

struct ViewerOverlayControls: View {
    @ObservedObject var controller: ViewerPanelController
    
    var body: some View {
            VStack {
            // Top overlay - image info
                HStack {
                    if let image = controller.currentImage {
                    HStack(spacing: 12) {
                        // Resolution info
                        Text("Resolution: \(Int(image.size.width)) × \(Int(image.size.height))")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                        
                        // Scale info
                        Text("Scale: \(String(format: "%.0f", controller.zoomLevel * 100))%")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                        
                        // Video time info (if applicable)
                        if controller.isVideoMode, controller.videoDuration > 0 {
                            Text("\(formatTime(controller.currentTime)) / \(formatTime(controller.videoDuration))")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(4)
                        }
                    }
                }
                Spacer()
                
                // Zoom controls
                HStack(spacing: 4) {
                    Button(action: { controller.zoomToFit() }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption)
                    }
                    .buttonStyle(ViewerButtonStyle())
                    
                    Button(action: { controller.zoomToActual() }) {
                        Text("100%")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(ViewerButtonStyle())
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 12)
            
            Spacer()
            
            // Center overlay - playback controls (for video)
            if controller.isVideoMode && controller.currentImage != nil {
                HStack(spacing: 20) {
                    // Play/Pause
                    Button(action: { controller.togglePlayback() }) {
                        Image(systemName: controller.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.8), radius: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .opacity(controller.showTransportOverlay ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: controller.showTransportOverlay)
            }
            
            Spacer()
        }
    }
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let frames = Int((time.truncatingRemainder(dividingBy: 1)) * 30) // Assuming 30fps
        return String(format: "%02d:%02d:%02d", minutes, seconds, frames)
    }
}

// MARK: - Transport Controls

struct ViewerTransportControls: View {
    @ObservedObject var controller: ViewerPanelController
    
    var body: some View {
        VStack(spacing: 0) {
            // Timeline
            if controller.isVideoMode && controller.videoDuration > 0 {
                ViewerTimeline(controller: controller)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
            }
            
            // Transport buttons
            HStack(spacing: 8) {
                // Left side - navigation
                HStack(spacing: 4) {
                    Button(action: { controller.stepBackward() }) {
                        Image(systemName: "backward.frame.fill")
                    }
                    .buttonStyle(TransportButtonStyle())
                    .disabled(!controller.isVideoMode)
                    
                    Button(action: { controller.jumpBackward() }) {
                        Image(systemName: "gobackward.10")
                    }
                    .buttonStyle(TransportButtonStyle())
                    .disabled(!controller.isVideoMode)
                    
                    Button(action: { controller.togglePlayback() }) {
                        Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(TransportButtonStyle(isPrimary: true))
                    .disabled(!controller.isVideoMode)
                    
                    Button(action: { controller.jumpForward() }) {
                        Image(systemName: "goforward.10")
                    }
                    .buttonStyle(TransportButtonStyle())
                    .disabled(!controller.isVideoMode)
                    
                    Button(action: { controller.stepForward() }) {
                        Image(systemName: "forward.frame.fill")
                    }
                    .buttonStyle(TransportButtonStyle())
                    .disabled(!controller.isVideoMode)
                }
                
                Spacer()
                
                // Center - time display
                if controller.isVideoMode {
                    Text(formatTime(controller.currentTime))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(minWidth: 60)
                }
                
                Spacer()
                
                // Right side - playback options
                HStack(spacing: 4) {
                    // Speed control
                    Menu {
                        Button("0.25x") { controller.setPlaybackSpeed(0.25) }
                        Button("0.5x") { controller.setPlaybackSpeed(0.5) }
                        Button("1.0x") { controller.setPlaybackSpeed(1.0) }
                        Button("1.5x") { controller.setPlaybackSpeed(1.5) }
                        Button("2.0x") { controller.setPlaybackSpeed(2.0) }
                    } label: {
                        Text("\(String(format: "%.2f", controller.playbackSpeed))x")
                            .font(.caption)
                    }
                    .buttonStyle(TransportButtonStyle())
                    .disabled(!controller.isVideoMode)
                    
                    // Loop toggle
                    Button(action: { controller.toggleLoop() }) {
                        Image(systemName: controller.isLooping ? "repeat.circle.fill" : "repeat.circle")
                    }
                    .buttonStyle(TransportButtonStyle())
                    .disabled(!controller.isVideoMode)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let frames = Int((time.truncatingRemainder(dividingBy: 1)) * 30)
        return String(format: "%02d:%02d:%02d", minutes, seconds, frames)
    }
}

// MARK: - Timeline

struct ViewerTimeline: View {
    @ObservedObject var controller: ViewerPanelController
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    
    var body: some View {
        VStack(spacing: 4) {
            // Timecode ruler
            TimelineRuler(
                duration: controller.videoDuration,
                currentTime: controller.currentTime
            )
            
            // Scrubber
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 6)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue)
                        .frame(width: progressWidth(geometry), height: 6)
                    
                    // Playhead
                    Rectangle()
                        .fill(Color.yellow)
                        .frame(width: 2, height: 16)
                        .offset(x: playheadOffset(geometry))
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    if !isDragging {
                                        isDragging = true
                                        controller.beginScrubbing()
                                    }
                                    
                                    let newValue = valueFromPosition(gesture.location.x, geometry: geometry)
                                    dragValue = newValue
                                    controller.scrub(to: newValue)
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    controller.endScrubbing()
                                }
                        )
                }
            }
            .frame(height: 16)
        }
    }
    
    private func progressWidth(_ geometry: GeometryProxy) -> CGFloat {
        let progress = controller.videoDuration > 0 ? (isDragging ? dragValue : controller.currentTime) / controller.videoDuration : 0
        return geometry.size.width * CGFloat(progress)
    }
    
    private func playheadOffset(_ geometry: GeometryProxy) -> CGFloat {
        let progress = controller.videoDuration > 0 ? (isDragging ? dragValue : controller.currentTime) / controller.videoDuration : 0
        return (geometry.size.width - 2) * CGFloat(progress)
    }
    
    private func valueFromPosition(_ x: CGFloat, geometry: GeometryProxy) -> Double {
        let progress = max(0, min(1, x / geometry.size.width))
        return controller.videoDuration * Double(progress)
    }
}

// MARK: - Timeline Ruler

struct TimelineRuler: View {
    let duration: Double
    let currentTime: Double
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let width = size.width
                let height = size.height
                
                // Draw tick marks
                let tickInterval = calculateTickInterval(duration: duration, width: width)
                let majorTicks = stride(from: 0, through: duration, by: tickInterval)
                
                for tick in majorTicks {
                    let x = (tick / duration) * width
                    
                    // Major tick
                    var tickPath = Path()
                    tickPath.move(to: CGPoint(x: x, y: height))
                    tickPath.addLine(to: CGPoint(x: x, y: height - 8))
                    context.stroke(tickPath, with: .color(.secondary), lineWidth: 1)
                    
                    // Time label
                    let timeText = formatTimeShort(tick)
                    context.draw(
                        Text(timeText)
                            .font(.caption2)
                            .foregroundColor(.secondary),
                        at: CGPoint(x: x, y: height - 12),
                        anchor: .center
                    )
                }
                
                // Draw minor ticks
                let minorTickInterval = tickInterval / 5
                let minorTicks = stride(from: 0, through: duration, by: minorTickInterval)
                
                for tick in minorTicks {
                    let x = (tick / duration) * width
                    
                    var tickPath = Path()
                    tickPath.move(to: CGPoint(x: x, y: height))
                    tickPath.addLine(to: CGPoint(x: x, y: height - 4))
                    context.stroke(tickPath, with: .color(.secondary.opacity(0.5)), lineWidth: 0.5)
                }
            }
        }
        .frame(height: 20)
    }
    
    private func calculateTickInterval(duration: Double, width: CGFloat) -> Double {
        let minPixelsPerTick: CGFloat = 80
        let maxTicks = Int(width / minPixelsPerTick)
        
        if maxTicks <= 0 { return duration }
        
        let roughInterval = duration / Double(maxTicks)
        
        // Round to nice intervals
        let niceIntervals = [1.0, 2.0, 5.0, 10.0, 15.0, 30.0, 60.0, 120.0, 300.0, 600.0]
        
        for interval in niceIntervals {
            if roughInterval <= interval {
                return interval
            }
        }
        
        return duration
    }
    
    private func formatTimeShort(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Button Styles

struct ViewerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(4)
            .background(Color.black.opacity(0.7))
            .foregroundColor(.white)
            .cornerRadius(4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct TransportButtonStyle: ButtonStyle {
    let isPrimary: Bool
    
    init(isPrimary: Bool = false) {
        self.isPrimary = isPrimary
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: isPrimary ? 16 : 14))
            .padding(isPrimary ? 8 : 6)
            .background(isPrimary ? Color.blue : Color.gray.opacity(0.2))
            .foregroundColor(isPrimary ? .white : .primary)
            .cornerRadius(isPrimary ? 8 : 6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
