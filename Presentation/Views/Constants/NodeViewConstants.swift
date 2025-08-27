//
//  NodeConstants.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 14.07.2025.
//

import SwiftUI

struct NodeViewConstants {
    // Node dimensions
    static let nodeWidth: CGFloat = PerformanceConstants.nodeWidth
    static let nodeHeight: CGFloat = PerformanceConstants.nodeHeight
    
    // Port dimensions
    static let portSize: CGFloat = PerformanceConstants.portSize
    static let portSpacing: CGFloat = PerformanceConstants.portSpacing // Distance between the ports
    static let portVerticalOffset: CGFloat = PerformanceConstants.portVerticalOffset // Distance from the edge of the node to the port
    
    // Node spacing and padding
    static let nodeSelectionPadding: CGFloat = PerformanceConstants.nodeSelectionPadding
    
    // Visual elements
    static let nodeCornerRadius: CGFloat = PerformanceConstants.nodeCornerRadius
    static let connectionLineWidth: CGFloat = PerformanceConstants.connectionLineWidth
    static let selectionBorderWidth: CGFloat = PerformanceConstants.selectionBorderWidth
    
    // Grid
    static let gridSpacing: CGFloat = PerformanceConstants.gridSpacing
    
    // MARK: - Node frame calculations
    
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
    
    // MARK: - Port positioning methods (improved for multiple ports)
    
    /// Возвращает позицию конкретного input порта
    /// - Parameters:
    ///   - nodePosition: Позиция ноды
    ///   - portIndex: Индекс порта (0-based)
    ///   - totalPorts: Общее количество портов
    static func inputPortPosition(at nodePosition: CGPoint, portIndex: Int, totalPorts: Int) -> CGPoint {
        let startX = nodePosition.x - (CGFloat(totalPorts - 1) * portSpacing) / 2
        let portX = startX + CGFloat(portIndex) * portSpacing
        let portY = nodePosition.y - nodeHeight/2 - portVerticalOffset
        
        return CGPoint(x: portX, y: portY)
    }
    
    /// Возвращает позицию конкретного output порта
    /// - Parameters:
    ///   - nodePosition: Позиция ноды
    ///   - portIndex: Индекс порта (0-based)
    ///   - totalPorts: Общее количество портов
    static func outputPortPosition(at nodePosition: CGPoint, portIndex: Int, totalPorts: Int) -> CGPoint {
        let startX = nodePosition.x - (CGFloat(totalPorts - 1) * portSpacing) / 2
        let portX = startX + CGFloat(portIndex) * portSpacing
        let portY = nodePosition.y + nodeHeight/2 + portVerticalOffset
        
        return CGPoint(x: portX, y: portY)
    }
    
    // MARK: - Legacy methods (для совместимости)
    
    /// Возвращает позицию единственного input порта (для совместимости)
    static func inputPortPosition(at nodePosition: CGPoint) -> CGPoint {
        return inputPortPosition(at: nodePosition, portIndex: 0, totalPorts: 1)
    }
    
    /// Возвращает позицию единственного output порта (для совместимости)
    static func outputPortPosition(at nodePosition: CGPoint) -> CGPoint {
        return outputPortPosition(at: nodePosition, portIndex: 0, totalPorts: 1)
    }
    
    // MARK: - Port area calculations
    
    /// Возвращает область, где могут находиться input порты
    static func inputPortsArea(at nodePosition: CGPoint, portCount: Int) -> CGRect {
        let width = max(portSize, CGFloat(portCount - 1) * portSpacing + portSize)
        let height = portSize
        let x = nodePosition.x - width/2
        let y = nodePosition.y - nodeHeight/2 - portVerticalOffset - height/2
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    /// Возвращает область, где могут находиться output порты
    static func outputPortsArea(at nodePosition: CGPoint, portCount: Int) -> CGRect {
        let width = max(portSize, CGFloat(portCount - 1) * portSpacing + portSize)
        let height = portSize
        let x = nodePosition.x - width/2
        let y = nodePosition.y + nodeHeight/2 + portVerticalOffset - height/2
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
} 
