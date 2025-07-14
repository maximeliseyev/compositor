//
//  CorrectorNode.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 14.07.2025.
//

import SwiftUI
import CoreImage

class CorrectorNode: BaseNode {
    init(position: CGPoint) {
        super.init(type: .corrector, position: position)
    }
    
    override func process(inputs: [CIImage?]) -> CIImage? {
        // For now, just pass through the first input
        return inputs.first ?? nil
    }
    
    override var title: String {
        return "Corrector"
    }
} 