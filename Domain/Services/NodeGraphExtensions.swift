//
//  NodeGraphExtensions.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 27.08.2025.
//
import Foundation
import SwiftUI
import CoreImage

// MARK: - Node Creation Extensions

extension NodeGraph {
    
    /// Добавляет ноду в граф
    /// Создает ноду указанного типа в заданной позиции и добавляет её в граф
    func addNode(type: NodeType, position: CGPoint) {
        let node = NodeFactory.createNode(type: type, position: position)
        addNode(node)
    }
    
    /// Добавляет ноду с параметрами в граф
    /// Создает ноду с пользовательскими параметрами и добавляет её в граф
    func addNode(type: NodeType, position: CGPoint, parameters: [String: Double]) {
        let node = NodeFactory.createNode(type: type, position: position, parameters: parameters)
        addNode(node)
    }
    
    /// Добавляет ноду из шаблона в граф
    /// Создает ноду на основе предопределенного шаблона и добавляет её в граф
    func addNode(from template: NodeTemplate) {
        let node = NodeFactory.createNodeFromTemplate(template)
        addNode(node)
    }
}

// MARK: - Convenience Methods

extension NodeGraph {
    
    /// Создает и добавляет несколько нод одновременно
    func addNodes(_ nodeSpecs: [(type: NodeType, position: CGPoint)]) {
        for spec in nodeSpecs {
            addNode(type: spec.type, position: spec.position)
        }
    }
    
    /// Создает и добавляет ноду с автоматическим позиционированием
    func addNode(type: NodeType, offset: CGPoint = .zero) {
        let position = calculateNextNodePosition(offset: offset)
        addNode(type: type, position: position)
    }
    
    /// Вычисляет позицию для следующей ноды
    private func calculateNextNodePosition(offset: CGPoint) -> CGPoint {
        let basePosition = CGPoint(x: 100, y: 100)
        let spacing = CGPoint(x: 200, y: 150)
        
        let nodeCount = nodes.count
        let row = nodeCount / 3
        let col = nodeCount % 3
        
        return CGPoint(
            x: basePosition.x + CGFloat(col) * spacing.x + offset.x,
            y: basePosition.y + CGFloat(row) * spacing.y + offset.y
        )
    }
}
