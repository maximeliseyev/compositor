//
//  VideoInspectorControls.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 19.07.2025.
//

import SwiftUI

struct VideoInspectorControls: View {
    @ObservedObject var node: InputNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Video Controls")
                .font(.headline)
            
            // Playback controls
            HStack {
                Button(action: {
                    if node.isVideoPlaying {
                        node.pauseVideo()
                    } else {
                        node.playVideo()
                    }
                }) {
                    HStack {
                        Image(systemName: node.isVideoPlaying ? "pause.fill" : "play.fill")
                        Text(node.isVideoPlaying ? "Pause" : "Play")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(node.videoDuration == 0)
            }
            
            // Timeline
            if node.videoDuration > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    // Time labels
                    HStack {
                        Text(formatTime(node.videoCurrentTime))
                            .font(.caption)
                            .monospacedDigit()
                        Spacer()
                        Text(formatTime(node.videoDuration))
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .foregroundColor(.secondary)
                    
                    // Scrubber
                    VideoScrubber(
                        currentTime: node.videoCurrentTime,
                        duration: node.videoDuration,
                        onSeek: { time in
                            node.seekVideo(to: time)
                        }
                    )
                }
            }
            
            // Video info
            VStack(alignment: .leading, spacing: 4) {
                if node.isVideoLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading video...")
                            .foregroundColor(.secondary)
                    }
                }
                
                if node.videoDuration > 0 {
                    HStack {
                        Text("Duration:")
                            .foregroundColor(.secondary)
                        Text(formatTime(node.videoDuration))
                        Spacer()
                    }
                    .font(.caption)
                }
            }
        }
    }
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
} 