//
//  NodeConstants.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 14.07.2025.
//

import SwiftUI

// MARK: - Node Visual Constants
struct NodeConstants {
    // Node dimensions
    static let nodeWidth: CGFloat = 80
    static let nodeHeight: CGFloat = 40
    
    // Port dimensions
    static let portSize: CGFloat = 10
    static let portOffset: CGFloat = 15 // Distance between ports
    
    // Node spacing and padding
    static let nodeSelectionPadding: CGFloat = 20
    static let portVerticalOffset: CGFloat = 30 // Distance from node center to port
    
    // Visual elements
    static let nodeCornerRadius: CGFloat = 8
    static let connectionLineWidth: CGFloat = 3
    static let selectionBorderWidth: CGFloat = 2
    
    // Grid
    static let gridSpacing: CGFloat = 40
    
    // Node frame calculations
    static func nodeFrame(at position: CGPoint) -> CGRect {
        return CGRect(
            x: position.x - nodeWidth/2,
            y: position.y - nodeHeight/2,
            width: nodeWidth,
            height: nodeHeight
        )
    }
    
    static func nodeHitFrame(at position: CGPoint) -> CGRect {
        return CGRect(
            x: position.x - nodeWidth/2 - nodeSelectionPadding,
            y: position.y - nodeHeight/2 - nodeSelectionPadding,
            width: nodeWidth + 2 * nodeSelectionPadding,
            height: nodeHeight + 2 * nodeSelectionPadding
        )
    }
    
    static func inputPortPosition(at nodePosition: CGPoint) -> CGPoint {
        return CGPoint(
            x: nodePosition.x,
            y: nodePosition.y - nodeHeight/2 - portSize/2
        )
    }
    
    static func outputPortPosition(at nodePosition: CGPoint) -> CGPoint {
        return CGPoint(
            x: nodePosition.x,
            y: nodePosition.y + nodeHeight/2 + portSize/2
        )
    }
} 