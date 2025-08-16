//
//  VideoScrubber.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 19.07.2025.
//

import SwiftUI

struct VideoScrubber: View {
    let currentTime: Double
    let duration: Double
    let onSeek: (Double) -> Void
    
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 4)
                    .cornerRadius(2)
                
                // Progress
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: progressWidth(geometry), height: 4)
                    .cornerRadius(2)
                
                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .shadow(radius: 1)
                    .offset(x: thumbOffset(geometry))
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                if !isDragging {
                                    isDragging = true
                                }
                                
                                let newValue = valueFromPosition(gesture.location.x, geometry: geometry)
                                dragValue = newValue
                                onSeek(newValue)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
            }
        }
        .frame(height: 20)
    }
    
    private func progressWidth(_ geometry: GeometryProxy) -> CGFloat {
        let progress = duration > 0 ? (isDragging ? dragValue : currentTime) / duration : 0
        return geometry.size.width * CGFloat(progress)
    }
    
    private func thumbOffset(_ geometry: GeometryProxy) -> CGFloat {
        let progress = duration > 0 ? (isDragging ? dragValue : currentTime) / duration : 0
        return (geometry.size.width - 12) * CGFloat(progress)
    }
    
    private func valueFromPosition(_ x: CGFloat, geometry: GeometryProxy) -> Double {
        let progress = max(0, min(1, x / geometry.size.width))
        return duration * Double(progress)
    }
} 