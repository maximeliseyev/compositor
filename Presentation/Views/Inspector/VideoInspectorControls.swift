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
                    if node.isPlaying {
                        node.pause()
                    } else {
                        node.play()
                    }
                }) {
                    HStack {
                        Image(systemName: node.isPlaying ? "pause.fill" : "play.fill")
                        Text(node.isPlaying ? "Pause" : "Play")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(node.duration == 0)
            }
            
            // Timeline
            if node.duration > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    // Time labels
                    HStack {
                        Text(formatTime(node.currentTime))
                            .font(.caption)
                            .monospacedDigit()
                        Spacer()
                        Text(formatTime(node.duration))
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .foregroundColor(.secondary)
                    
                    // Scrubber
                    VideoScrubber(
                        currentTime: node.currentTime,
                        duration: node.duration,
                        onSeek: { time in
                            node.seek(to: time)
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
                
                if node.duration > 0 {
                    HStack {
                        Text("Duration:")
                            .foregroundColor(.secondary)
                        Text(formatTime(node.duration))
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