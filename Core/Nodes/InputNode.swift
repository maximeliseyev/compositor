//
//  InputNode.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 14.07.2025.
//

import SwiftUI
import CoreImage

class InputNode: BaseNode {
    @Published var nsImage: NSImage?
    @Published var ciImage: CIImage?
    
    init(position: CGPoint) {
        super.init(type: .input, position: position)
    }
    
    func loadImage(from url: URL) {
        if let nsImage = NSImage(contentsOf: url) {
            self.nsImage = nsImage
            if let tiffData = nsImage.tiffRepresentation, let ciImage = CIImage(data: tiffData) {
                self.ciImage = ciImage
            } else {
                self.ciImage = nil
            }
        } else {
            self.nsImage = nil
            self.ciImage = nil
        }
    }
    
    override func process(inputs: [CIImage?]) -> CIImage? {
        return ciImage
    }
    
    override var title: String {
        return "Input"
    }
} 
