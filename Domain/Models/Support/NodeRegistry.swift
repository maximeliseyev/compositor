//
//  NodeRegistry.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 14.07.2025.
//

import SwiftUI
import CoreImage

// MARK: - Node Creator Protocol

/// Протокол для создания нод
@MainActor
protocol NodeCreator {
    func createNode(type: NodeType, position: CGPoint) -> BaseNode
    func getDefaultParameters(for type: NodeType) -> [String: Any]
    func isSupported(type: NodeType) -> Bool
}

// MARK: - Node Inspector Creator Protocol

/// Протокол для создания инспекторов нод
protocol NodeInspectorCreator {
    func createInspector(for node: BaseNode) -> AnyView
    func isSupported(node: BaseNode) -> Bool
}

// MARK: - Node Registry

/// Центральный реестр для всех типов нод
/// Позволяет регистрировать новые типы нод без изменения существующего кода
@MainActor
class NodeRegistry: ObservableObject {
    
    // MARK: - Singleton
    static let shared = NodeRegistry()
    
    // MARK: - Private Properties
    private var nodeCreators: [NodeType: NodeCreator] = [:]
    private var inspectorCreators: [String: NodeInspectorCreator] = [:]
    private var defaultParameters: [NodeType: [String: Any]] = [:]
    
    // MARK: - Initialization
    private init() {
        registerDefaultNodes()
        registerDefaultInspectors()
    }
    
    // MARK: - Node Registration
    
    /// Регистрирует создателя нод для определенного типа
    func registerNodeCreator(_ creator: NodeCreator, for type: NodeType) {
        nodeCreators[type] = creator
    }
    
    /// Регистрирует создателя инспекторов для определенного класса нод
    func registerInspectorCreator(_ creator: NodeInspectorCreator, for className: String) {
        inspectorCreators[className] = creator
    }
    
    /// Регистрирует параметры по умолчанию для типа ноды
    func registerDefaultParameters(_ parameters: [String: Any], for type: NodeType) {
        defaultParameters[type] = parameters
    }
    
    // MARK: - Node Creation
    
    /// Создает ноду указанного типа
    func createNode(type: NodeType, position: CGPoint) -> BaseNode {
        guard let creator = nodeCreators[type] else {
            fatalError("No creator registered for node type: \(type)")
        }
        
        let node = creator.createNode(type: type, position: position)
        
        // Устанавливаем параметры по умолчанию
        if let defaults = defaultParameters[type] {
            for (key, value) in defaults {
                node.setParameter(key: key, value: value)
            }
        }
        
        return node
    }
    
    /// Создает инспектор для ноды
    func createInspector(for node: BaseNode) -> AnyView {
        let className = String(describing: type(of: node))
        
        // Ищем специфичный инспектор
        if let creator = inspectorCreators[className] {
            return creator.createInspector(for: node)
        }
        
        // Ищем инспектор по базовому классу
        if let baseCreator = inspectorCreators["BaseNode"] {
            return baseCreator.createInspector(for: node)
        }
        
        // Fallback к универсальному инспектору
        return AnyView(BaseNodeInspector(node: node))
    }
    
    // MARK: - Utility Methods
    
    /// Получает все зарегистрированные типы нод
    func getRegisteredNodeTypes() -> [NodeType] {
        return Array(nodeCreators.keys)
    }
    
    /// Проверяет поддержку типа ноды
    func isNodeTypeSupported(_ type: NodeType) -> Bool {
        return nodeCreators[type] != nil
    }
    
    /// Получает параметры по умолчанию для типа ноды
    func getDefaultParameters(for type: NodeType) -> [String: Any] {
        return defaultParameters[type] ?? [:]
    }
    
    // MARK: - Default Registration
    
    private func registerDefaultNodes() {
        // Регистрируем стандартные ноды
        registerNodeCreator(StandardNodeCreator(), for: .view)
        registerNodeCreator(StandardNodeCreator(), for: .input)
        registerNodeCreator(StandardNodeCreator(), for: .blur)
        registerNodeCreator(StandardNodeCreator(), for: .brightness)
        
        // Регистрируем параметры по умолчанию
        registerDefaultParameters([
            "radius": 10.0,
            "intensity": 1.0
        ], for: .blur)
        
        registerDefaultParameters([
            "brightness": 0.0,
            "contrast": 1.0,
            "saturation": 1.0
        ], for: .brightness)
    }
    
    private func registerDefaultInspectors() {
        // Регистрируем универсальный инспектор как fallback
        registerInspectorCreator(UniversalInspectorCreator(), for: "BaseNode")
    }
}

// MARK: - Standard Node Creator

/// Стандартный создатель нод
@MainActor
class StandardNodeCreator: NodeCreator {
    
    func createNode(type: NodeType, position: CGPoint) -> BaseNode {
        switch type {
        case .view:
            return ViewNode(type: .view, position: position)
        case .input:
            return InputNode(position: position)
        case .blur:
            return BlurNode(type: .blur, position: position)
        case .brightness:
            return BrightnessNode(type: .brightness, position: position)
        }
    }
    
    func getDefaultParameters(for type: NodeType) -> [String: Any] {
        switch type {
        case .blur:
            return ["radius": 10.0, "intensity": 1.0]
        case .brightness:
            return ["brightness": 0.0, "contrast": 1.0, "saturation": 1.0]
        default:
            return [:]
        }
    }
    
    func isSupported(type: NodeType) -> Bool {
        return [.view, .input, .blur, .brightness].contains(type)
    }
}

// MARK: - Universal Inspector Creator

/// Универсальный создатель инспекторов
class UniversalInspectorCreator: NodeInspectorCreator {
    
    func createInspector(for node: BaseNode) -> AnyView {
        // Используем существующую логику из NodeInspectorFactory
        switch node {
        case let inputNode as InputNode:
            return AnyView(InputNodeInspector(node: inputNode))
        case let viewNode as ViewNode:
            return AnyView(ViewNodeInspector(node: viewNode))
        case let metalNode as MetalNode:
            return AnyView(MetalNodeInspector(node: metalNode))
        case let blurNode as BlurNode:
            return AnyView(BlurNodeInspector(node: blurNode))
        case let brightnessNode as BrightnessNode:
            return AnyView(BrightnessNodeInspector(node: brightnessNode))
        default:
            return AnyView(BaseNodeInspector(node: node))
        }
    }
    
    func isSupported(node: BaseNode) -> Bool {
        return true // Поддерживает все типы нод
    }
}

// MARK: - Node Inspector Extensions

/// Инспектор для BrightnessNode
struct BrightnessNodeInspector: View {
    @ObservedObject var node: BrightnessNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Brightness & Contrast")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Brightness")
                    Spacer()
                    Text(String(format: "%.2f", node.brightness))
                        .font(.caption)
                        .monospacedDigit()
                }
                Slider(value: $node.brightness, in: -1.0...1.0)
                
                HStack {
                    Text("Contrast")
                    Spacer()
                    Text(String(format: "%.2f", node.contrast))
                        .font(.caption)
                        .monospacedDigit()
                }
                Slider(value: $node.contrast, in: 0.0...2.0)
                
                HStack {
                    Text("Saturation")
                    Spacer()
                    Text(String(format: "%.2f", node.saturation))
                        .font(.caption)
                        .monospacedDigit()
                }
                Slider(value: $node.saturation, in: 0.0...2.0)
            }
            
            Button("Reset to Defaults") {
                node.resetToDefaults()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}
