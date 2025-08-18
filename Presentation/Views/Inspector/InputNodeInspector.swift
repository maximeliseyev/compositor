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
                    allowedContentTypes: getSupportedFileTypes(),
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        if let url = urls.first {
                            Task {
                                await node.loadMediaFile(from: url)
                            }
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
                                Text(getMediaTypeDisplayName())
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

            // Media Info Section
            if let mediaInfo = node.mediaInfo {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Media Info")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        if let duration = mediaInfo.duration {
                            HStack {
                                Text("Duration:")
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2fs", duration))
                                Spacer()
                            }
                            .font(.caption)
                        }
                        
                        if let frameRate = mediaInfo.frameRate {
                            HStack {
                                Text("Frame Rate:")
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f fps", frameRate))
                                Spacer()
                            }
                            .font(.caption)
                        }
                        
                        if let resolution = mediaInfo.resolution {
                            HStack {
                                Text("Resolution:")
                                    .foregroundColor(.secondary)
                                Text("\(Int(resolution.width))×\(Int(resolution.height))")
                                Spacer()
                            }
                            .font(.caption)
                        }
                        
                        if let bitDepth = mediaInfo.bitDepth {
                            HStack {
                                Text("Bit Depth:")
                                    .foregroundColor(.secondary)
                                Text("\(bitDepth)-bit")
                                Spacer()
                            }
                            .font(.caption)
                        }
                        
                        HStack {
                            Text("Alpha Channel:")
                                .foregroundColor(.secondary)
                            Text(mediaInfo.hasAlpha ? "Yes" : "No")
                                .foregroundColor(mediaInfo.hasAlpha ? .green : .red)
                            Spacer()
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }
    
    private func getSupportedFileTypes() -> [UTType] {
        return [
            // Video formats
            .movie, .video, .quickTimeMovie, .mpeg4Movie,
            // Image formats  
            .image, .png, .jpeg, .tiff, .gif, .bmp, .heic, .webP
        ]
    }
    
    private func getMediaTypeDisplayName() -> String {
        if let format = node.mediaFormat {
            return format.rawValue
        }
        
        switch node.mediaType {
        case .image:
            return "Image"
        case .video:
            return "Video"
        case .proRes:
            return "ProRes"
        }
    }
    
    private var mediaTypeIcon: String {
        switch node.mediaType {
        case .image:
            return "photo"
        case .video:
            return "video"
        case .proRes:
            return "proRes"
        }
    }
    
    private var mediaTypeColor: Color {
        switch node.mediaType {
        case .image:
            return .cyan
        case .video:
            return .purple
        case .proRes:
            return .orange
        }
    }
} 
