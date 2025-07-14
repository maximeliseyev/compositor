//
//  ViewerPanelController.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 14.07.2025.
//


import SwiftUI

class ViewerPanelController: ObservableObject {
    @Published var currentImage: NSImage?
    
    func updateImage(_ image: NSImage?) {
        currentImage = image
    }
}
