//
//  InputNodeInspector.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 19.07.2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct InputNodeInspector: View {
    @ObservedObject var node: InputNode
    @State private var showingFilePicker = false
    @State private var isPlaying = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Media Loading Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Media Source")
                    .font(.headline)
                
                Button(action: {
                    showingFilePicker = true
                }) {
                    HStack {
                        Image(systemName: "folder")
                        Text("Load Media File...")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .fileImporter(
                    isPresented: $showingFilePicker,
                    allowedContentTypes: InputNode.getSupportedFileTypes(),
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        if let url = urls.first {
                            node.loadMedia(from: url)
                        }
                    case .failure(let error):
                        print("File picker error: \(error)")
                    }
                }
                
                // File info
                if node.fileName != nil || node.fileSize != nil {
                    VStack(alignment: .leading, spacing: 4) {
                        if let fileName = node.fileName {
                            HStack {
                                Text("File:")
                                    .foregroundColor(.secondary)
                                Text(fileName)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .font(.caption)
                        }
                        
                        if let fileSize = node.fileSize {
                            HStack {
                                Text("Size:")
                                    .foregroundColor(.secondary)
                                Text(fileSize)
                                Spacer()
                            }
                            .font(.caption)
                        }
                        
                        HStack {
                            Text("Type:")
                                .foregroundColor(.secondary)
                            HStack(spacing: 4) {
                                Image(systemName: mediaTypeIcon)
                                Text(node.mediaType == .image ? "Image" : "Video")
                            }
                            .foregroundColor(mediaTypeColor)
                            Spacer()
                        }
                        .font(.caption)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
                }
            }

            // Video Controls Section
            if node.mediaType == .video, node.videoURL != nil {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Playback")
                        .font(.headline)

                    HStack(spacing: 12) {
                        Button(action: {
                            if node.isVideoPlaying {
                                node.pauseVideo()
                            } else {
                                node.playVideo()
                            }
                        }) {
                            Image(systemName: node.isVideoPlaying ? "pause.fill" : "play.fill")
                        }
                        .buttonStyle(.bordered)

                        Text(String(format: "%.1fs / %.1fs", node.videoCurrentTime, node.videoDuration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Simple scrubber
                    Slider(value: Binding(
                        get: { node.videoCurrentTime },
                        set: { newValue in node.seekVideo(to: newValue) }
                    ), in: 0...max(0.1, node.videoDuration))
                }
            }
        }
    }
    
    private var mediaTypeIcon: String {
        switch node.mediaType {
        case .image:
            return "photo"
        case .video:
            return "video"
        }
    }
    
    private var mediaTypeColor: Color {
        switch node.mediaType {
        case .image:
            return .cyan
        case .video:
            return .purple
        }
    }
} 