//
//  NodeFactory.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 12.08.2025.
//

import SwiftUI
import CoreImage

/// Фабрика для создания нод с поддержкой различных рендереров
class NodeFactory {
    
    /// Создает ноду указанного типа (по умолчанию использует Metal)
    static func createNode(type: NodeType, position: CGPoint) -> BaseNode {
        switch type {
        case .view:
            return ViewNode(type: type, position: position)
        case .input:
            return InputNode(position: position)
        case .corrector:
            // По умолчанию создаем Metal версию для корректора
            return MetalCorrectorNode(type: type, position: position)
        case .metalCorrector:
            return MetalCorrectorNode(type: type, position: position)
        case .metalBlur:
            return MetalBlurNode(type: type, position: position)
        case .colorWheels:
            return ColorWheelsNode(position: position)
        }
    }
    
    /// Создает ноду с предпочтительным рендерером
    static func createNode(type: NodeType, position: CGPoint, preferredRenderer: RendererType) -> BaseNode {
        switch preferredRenderer {
        case .metal:
            return createMetalNode(type: type, position: position)
        case .coreImage:
            return createCoreImageNode(type: type, position: position)
        case .auto:
            return createNode(type: type, position: position)
        }
    }
    
    /// Создает Metal ноду если возможно, иначе Core Image
    private static func createMetalNode(type: NodeType, position: CGPoint) -> BaseNode {
        switch type {
        case .corrector:
            return MetalCorrectorNode(type: type, position: position)
        case .metalCorrector:
            return MetalCorrectorNode(type: type, position: position)
        case .metalBlur:
            return MetalBlurNode(type: type, position: position)
        default:
            return createNode(type: type, position: position)
        }
    }
    
    /// Создает Core Image ноду
    private static func createCoreImageNode(type: NodeType, position: CGPoint) -> BaseNode {
        switch type {
        case .corrector, .metalCorrector:
            return CorrectorNode(position: position)
        case .metalBlur:
            return CorrectorNode(position: position) // Fallback
        default:
            return createNode(type: type, position: position)
        }
    }
    
    /// Получает доступные типы нод для указанного рендерера
    static func getAvailableNodeTypes(for renderer: RendererType) -> [NodeType] {
        switch renderer {
        case .metal:
            return NodeType.allCases.filter { type in
                switch type {
                case .metalCorrector, .metalBlur, .corrector:
                    return true
                default:
                    return true // Все ноды поддерживаются
                }
            }
        case .coreImage:
            return NodeType.allCases.filter { type in
                switch type {
                case .metalCorrector, .metalBlur:
                    return false // Эти ноды специфичны для Metal
                default:
                    return true
                }
            }
        case .auto:
            return NodeType.allCases
        }
    }
    
    /// Проверяет поддержку типа ноды для указанного рендерера
    static func isNodeTypeSupported(_ type: NodeType, by renderer: RendererType) -> Bool {
        switch renderer {
        case .metal:
            return true // Metal поддерживает все типы нод
        case .coreImage:
            switch type {
            case .metalCorrector, .metalBlur:
                return false
            default:
                return true
            }
        case .auto:
            return true
        }
    }
}

// MARK: - Renderer Types

enum RendererType: String, CaseIterable {
    case metal = "Metal"
    case coreImage = "Core Image"
    case auto = "Auto"
    
    var displayName: String {
        return rawValue
    }
    
    var description: String {
        switch self {
        case .metal:
            return "Use Metal for GPU acceleration"
        case .coreImage:
            return "Use Core Image framework"
        case .auto:
            return "Automatically choose best available"
        }
    }
}

// MARK: - Node Creation Extensions

extension NodeGraph {
    /// Добавляет ноду в граф с указанным рендерером
    func addNode(type: NodeType, position: CGPoint, renderer: RendererType = .auto) {
        let node = NodeFactory.createNode(type: type, position: position, preferredRenderer: renderer)
        nodes.append(node)
    }
    
    /// Добавляет Metal ноду если доступна
    func addMetalNode(type: NodeType, position: CGPoint) {
        let node = NodeFactory.createNode(type: type, position: position, preferredRenderer: .metal)
        nodes.append(node)
    }
}
