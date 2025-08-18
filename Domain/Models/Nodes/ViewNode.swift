//
//  ViewNode.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 14.07.2025.
//

import SwiftUI
import CoreImage

class ViewNode: BaseNode {
    weak var viewerPanel: ViewerPanelController?
    
    @Published var currentImage: NSImage?
    
    override init(type: NodeType, position: CGPoint) {
            super.init(type: type, position: position)
        }
    
    convenience init(position: CGPoint, viewerPanel: ViewerPanelController) {
        self.init(type: .view, position: position)
        self.viewerPanel = viewerPanel
    }
    
    override func process(inputs: [CIImage?]) -> CIImage? {
        guard let input = inputs.first else {
            // Если нет входа, очищаем viewer
            updateViewer(with: nil)
            return nil
        }
        
        // Обновляем viewer с новым изображением
        updateViewer(with: input)
        
        // View нода просто пропускает изображение дальше
        return input
    }
    
    private func updateViewer(with ciImage: CIImage?) {
        DispatchQueue.main.async { [weak self] in
            if let ciImage = ciImage {
                let rep = NSCIImageRep(ciImage: ciImage)
                let nsImage = NSImage(size: rep.size)
                nsImage.addRepresentation(rep)
                self?.currentImage = nsImage
                self?.viewerPanel?.updateImage(nsImage)
            } else {
                self?.currentImage = nil
                self?.viewerPanel?.updateImage(nil)
            }
        }
    }
}
