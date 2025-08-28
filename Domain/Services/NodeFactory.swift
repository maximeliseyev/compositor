import SwiftUI
import CoreImage
import Foundation

// MARK: - Node Factory

/// Универсальная фабрика для создания нод
/// Использует центральный реестр для масштабируемости
@MainActor
class NodeFactory {
    
    // MARK: - Public Methods
    
    /// Создает ноду указанного типа
    static func createNode(type: NodeType, position: CGPoint) -> BaseNode {
        return NodeRegistry.shared.createNode(type: type, position: position)
    }
    
    /// Создает ноду с пользовательскими параметрами
    static func createNode(type: NodeType, position: CGPoint, parameters: [String: Any]) -> BaseNode {
        let node = createNode(type: type, position: position)
        
        // Переопределяем параметры пользовательскими значениями
        for (key, value) in parameters {
            node.setParameter(key: key, value: value)
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
        return NodeRegistry.shared.getRegisteredNodeTypes()
    }
    
    /// Проверяет поддержку типа ноды
    static func isNodeTypeSupported(_ type: NodeType) -> Bool {
        return NodeRegistry.shared.isNodeTypeSupported(type)
    }
    
    /// Получает параметры по умолчанию для типа ноды
    static func getDefaultParameters(for type: NodeType) -> [String: Any] {
        return NodeRegistry.shared.getDefaultParameters(for: type)
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
    let parameters: [String: Any]
    let name: String
    let description: String
    
    init(type: NodeType, position: CGPoint, parameters: [String: Any] = [:], name: String = "", description: String = "") {
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
            ),
            NodeTemplate(
                type: .brightness,
                position: .zero,
                parameters: ["brightness": 0.2, "contrast": 1.2, "saturation": 0.8],
                name: "Warm Tone",
                description: "Теплые тона для портретной съемки"
            ),
            NodeTemplate(
                type: .brightness,
                position: .zero,
                parameters: ["brightness": -0.1, "contrast": 1.5, "saturation": 1.3],
                name: "High Contrast",
                description: "Высокий контраст для драматических эффектов"
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


