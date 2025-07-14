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
        ZStack {
            // Фон
            Rectangle()
                .fill(Color.black)
            
            if let image = controller.currentImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Placeholder когда нет изображения
                VStack(spacing: 16) {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("Viewer")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Text("No image connected to Viewer node")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            VStack {
                HStack {
                    if let image = controller.currentImage {
                        Text("Resolution: \(Int(image.size.width)) x \(Int(image.size.height))")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding(12)
        }
        .border(Color.gray.opacity(0.3), width: 1)
    }
}
