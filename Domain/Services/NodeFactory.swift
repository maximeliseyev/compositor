//
//  NodeFactory.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 12.08.2025.
//

import SwiftUI
import CoreImage
import Foundation

// Импортируем типы нод
@_exported import struct Foundation.UUID

// MARK: - Node Factory

/// Универсальная фабрика для создания нод с поддержкой Metal
/// Все ноды оптимизированы для работы с Metal рендерером
@MainActor
class NodeFactory {
    
    // MARK: - Node Creation Registry
    
    /// Реестр создателей нод для каждого типа
    private static let nodeCreators: [NodeType: (CGPoint) -> BaseNode] = [
        .view: { position in ViewNode(type: .view, position: position) },
        .input: { position in InputNode(position: position) },
        .blur: { position in BlurNode(type: .blur, position: position) }
    ]
    
    /// Реестр параметров по умолчанию для каждого типа ноды
    private static let defaultParameters: [NodeType: [String: Double]] = [
        .blur: ["radius": 10.0, "intensity": 1.0],
        .input: [:],
        .view: [:]
    ]
    
    // MARK: - Public Methods
    
    /// Создает ноду указанного типа
    /// Все ноды создаются с поддержкой Metal
    static func createNode(type: NodeType, position: CGPoint) -> BaseNode {
        guard let creator = nodeCreators[type] else {
            fatalError("Unsupported node type: \(type)")
        }
        
        let node = creator(position)
        
        // Устанавливаем параметры по умолчанию
        if let defaults = defaultParameters[type] {
            node.parameters = defaults
        }
        
        return node
    }
    
    /// Создает ноду с пользовательскими параметрами
    static func createNode(type: NodeType, position: CGPoint, parameters: [String: Double]) -> BaseNode {
        let node = createNode(type: type, position: position)
        
        // Переопределяем параметры пользовательскими значениями
        for (key, value) in parameters {
            node.parameters[key] = value
        }
        
        return node
    }
    
    /// Создает копию ноды
    static func duplicateNode(_ node: BaseNode, at position: CGPoint) -> BaseNode {
        let newNode = createNode(type: node.type, position: position)
        
        // Копируем все параметры
        newNode.parameters = node.parameters
        
        return newNode
    }
    
    /// Создает ноду из шаблона
    static func createNodeFromTemplate(_ template: NodeTemplate) -> BaseNode {
        return createNode(type: template.type, position: template.position, parameters: template.parameters)
    }
    
    // MARK: - Utility Methods
    
    /// Получает все доступные типы нод
    static func getAvailableNodeTypes() -> [NodeType] {
        return Array(nodeCreators.keys)
    }
    
    /// Проверяет поддержку типа ноды
    static func isNodeTypeSupported(_ type: NodeType) -> Bool {
        return nodeCreators[type] != nil
    }
    
    /// Получает параметры по умолчанию для типа ноды
    static func getDefaultParameters(for type: NodeType) -> [String: Double] {
        return defaultParameters[type] ?? [:]
    }
    
    /// Получает метаданные для типа ноды
    static func getNodeMetadata(for type: NodeType) -> NodeMetadata {
        return type.metadata
    }
}

// MARK: - Node Template

struct NodeTemplate {
    let type: NodeType
    let position: CGPoint
    let parameters: [String: Double]
    let name: String
    let description: String
    
    init(type: NodeType, position: CGPoint, parameters: [String: Double] = [:], name: String = "", description: String = "") {
        self.type = type
        self.position = position
        self.parameters = parameters
        self.name = name.isEmpty ? type.displayName : name
        self.description = description.isEmpty ? type.description : description
    }
}

// MARK: - Predefined Templates

extension NodeFactory {
    /// Создает предопределенные шаблоны нод
    static func getPredefinedTemplates() -> [NodeTemplate] {
        return [
            NodeTemplate(
                type: .blur,
                position: .zero,
                parameters: ["radius": 5.0, "intensity": 0.5],
                name: "Light Blur",
                description: "Легкое размытие для смягчения изображения"
            ),
            NodeTemplate(
                type: .blur,
                position: .zero,
                parameters: ["radius": 20.0, "intensity": 1.0],
                name: "Heavy Blur",
                description: "Сильное размытие для создания эффекта глубины"
            ),
            NodeTemplate(
                type: .blur,
                position: .zero,
                parameters: ["radius": 50.0, "intensity": 0.8],
                name: "Background Blur",
                description: "Размытие фона для портретной съемки"
            )
        ]
    }
    
    /// Создает шаблон по умолчанию для типа ноды
    static func createDefaultTemplate(for type: NodeType, at position: CGPoint) -> NodeTemplate {
        return NodeTemplate(
            type: type,
            position: position,
            parameters: getDefaultParameters(for: type),
            name: type.displayName,
            description: type.description
        )
    }
}


