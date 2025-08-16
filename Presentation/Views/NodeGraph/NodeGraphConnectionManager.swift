//
//  NodeGraphConnectionManager.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 17.07.2025.
//

import SwiftUI
import Foundation

/// Управляет соединениями между нодами, включая drag & drop операции
@MainActor
class NodeGraphConnectionManager: ObservableObject {
    // MARK: - Properties
    
    @Published var connectionDragFromNodeID: UUID? = nil
    @Published var connectionDragFromPortID: UUID? = nil
    @Published var connectionDragFromPosition: CGPoint? = nil
    @Published var connectionDragCurrentPosition: CGPoint? = nil
    @Published var connectionDragToNodeID: UUID? = nil
    @Published var connectionDragToPortID: UUID? = nil
    
    // Свойства для работы с существующими связями
    @Published var draggedConnection: NodeConnection? = nil
    @Published var isDraggingFromInput: Bool = false // true если тянем от input порта, false если от output
    
    private var lastPreviewUpdateTime: TimeInterval = 0
    private let maxUpdateFrequency: TimeInterval = 1.0 / 60.0 // 60 FPS
    
    // MARK: - Connection Drag Management
    
    func startPortConnection(fromNodeID: UUID, fromPortID: UUID, portPosition: CGPoint, cache: NodeGraphCache) {
        guard let fromNode = cache.getCachedNode(id: fromNodeID),
              let _ = (fromNode.inputPorts + fromNode.outputPorts).first(where: { $0.id == fromPortID }) else {
            return
        }
        
        connectionDragFromNodeID = fromNodeID
        connectionDragFromPortID = fromPortID
        connectionDragFromPosition = portPosition
        connectionDragCurrentPosition = portPosition
        connectionDragToNodeID = nil
        connectionDragToPortID = nil
        draggedConnection = nil
        isDraggingFromInput = false
    }
    
    // MARK: - Existing Connection Drag Management
    
    func startConnectionDrag(connection: NodeConnection, dragPosition: CGPoint, cache: NodeGraphCache, nodeGraph: NodeGraph) {
        // Удаляем существующую связь из графа
        nodeGraph.removeConnection(connection)
        
        // Определяем, какой конец ближе к точке клика
        guard let fromNode = cache.getCachedNode(id: connection.fromNode),
              let toNode = cache.getCachedNode(id: connection.toNode) else {
            return
        }
        
        let connectionPoints = cache.getCachedConnectionPoints(for: connection, fromNode: fromNode, toNode: toNode)
        let distanceToStart = cache.distance(from: dragPosition, to: connectionPoints.0)
        let distanceToEnd = cache.distance(from: dragPosition, to: connectionPoints.1)
        
        // Устанавливаем параметры для перетаскивания
        draggedConnection = connection
        
        if distanceToStart < distanceToEnd {
            // Тянем от output порта (начало связи) - меняем input порт
            connectionDragFromNodeID = connection.toNode // Фиксированная сторона (input)
            connectionDragFromPortID = connection.toPort
            connectionDragFromPosition = connectionPoints.1 // Фиксированная точка (input)
            connectionDragCurrentPosition = dragPosition
            isDraggingFromInput = false // Тянем от output стороны
        } else {
            // Тянем от input порта (конец связи) - меняем output порт
            connectionDragFromNodeID = connection.fromNode // Фиксированная сторона (output)
            connectionDragFromPortID = connection.fromPort
            connectionDragFromPosition = connectionPoints.0 // Фиксированная точка (output)
            connectionDragCurrentPosition = dragPosition
            isDraggingFromInput = true // Тянем от input стороны
        }
        
        connectionDragToNodeID = nil
        connectionDragToPortID = nil
    }
    
    func updateConnectionDrag(to position: CGPoint, cache: NodeGraphCache) {
        let now = CACurrentMediaTime()
        if now - lastPreviewUpdateTime < maxUpdateFrequency { return }
        lastPreviewUpdateTime = now
        
        connectionDragCurrentPosition = position
        
        let (targetNode, targetPort) = findTargetAtPosition(position, cache: cache)
        connectionDragToNodeID = targetNode?.id
        connectionDragToPortID = targetPort?.id
    }
    
    func endPortConnection(toNodeID: UUID, toPortID: UUID, cache: NodeGraphCache, nodeGraph: NodeGraph) {
        guard let toNode = cache.getCachedNode(id: toNodeID),
              let _ = (toNode.inputPorts + toNode.outputPorts).first(where: { $0.id == toPortID }) else {
            // Если это была существующая связь, восстанавливаем её
            if let draggedConnection = draggedConnection {
                nodeGraph.addConnection(draggedConnection)
            }
            resetConnectionDrag()
            return
        }
                
        if let targetNodeID = connectionDragToNodeID,
           let targetPortID = connectionDragToPortID,
           let fromNodeID = connectionDragFromNodeID,
           let fromPortID = connectionDragFromPortID,
           let fromNode = cache.getCachedNode(id: fromNodeID),
           let targetNode = cache.getCachedNode(id: targetNodeID),
           let fromPort = (fromNode.inputPorts + fromNode.outputPorts).first(where: { $0.id == fromPortID }),
           let targetPort = (targetNode.inputPorts + targetNode.outputPorts).first(where: { $0.id == targetPortID }) {
            
            if draggedConnection != nil {
                // Переподключаем существующую связь
                if isDraggingFromInput {
                    // Тянули от input порта - создаем новое соединение с новым output портом
                    // Фиксированная сторона: input порт (fromNode, fromPort)
                    // Новая сторона: output порт (targetNode, targetPort)
                    if targetPort.type == .output && fromPort.type == .input {
                        let _ = nodeGraph.connectPorts(fromNode: targetNode, fromPort: targetPort, toNode: fromNode, toPort: fromPort)
                    }
                } else {
                    // Тянули от output порта - создаем новое соединение с новым input портом
                    // Фиксированная сторона: output порт (fromNode, fromPort)
                    // Новая сторона: input порт (targetNode, targetPort)
                    if fromPort.type == .output && targetPort.type == .input {
                        let _ = nodeGraph.connectPorts(fromNode: fromNode, fromPort: fromPort, toNode: targetNode, toPort: targetPort)
                    }
                }
            } else {
                // Создаем новую связь (обычный режим)
                if fromPort.type == NodePortType.output && targetPort.type == NodePortType.input {
                    let _ = nodeGraph.connectPorts(fromNode: fromNode, fromPort: fromPort, toNode: targetNode, toPort: targetPort)
                } else if fromPort.type == NodePortType.input && targetPort.type == NodePortType.output {
                    let _ = nodeGraph.connectPorts(fromNode: targetNode, fromPort: targetPort, toNode: fromNode, toPort: fromPort)
                }
            }
        } else {
            // Если не удалось подключить и это была существующая связь, восстанавливаем её
            if let draggedConnection = draggedConnection {
                nodeGraph.addConnection(draggedConnection)
            }
        }
        
        resetConnectionDrag()
    }
    
    func endConnectionDragWithoutTarget(nodeGraph: NodeGraph) {
        // Если это была существующая связь, удаляем её
        if let draggedConnection = draggedConnection {
            // Связь уже была удалена при начале перетаскивания, просто не восстанавливаем
            print("Удаляем связь: \(draggedConnection.id)")
        }
        
        resetConnectionDrag()
    }
    
    func resetConnectionDrag() {
        connectionDragFromNodeID = nil
        connectionDragFromPortID = nil
        connectionDragFromPosition = nil
        connectionDragCurrentPosition = nil
        connectionDragToNodeID = nil
        connectionDragToPortID = nil
        draggedConnection = nil
        isDraggingFromInput = false
    }
    
    // MARK: - Port Finding
    
    func findTargetAtPosition(_ position: CGPoint, cache: NodeGraphCache) -> (BaseNode?, NodePort?) {
        let snapDistance: CGFloat = 20
        var closestNode: BaseNode? = nil
        var closestPort: NodePort? = nil
        var closestDistance: CGFloat = snapDistance
        
        // Используем кэшированные ноды для быстрого поиска
        for node in cache.getAllCachedNodes() {
            // Сначала проверяем, находится ли точка рядом с нодой
            let nodeDistance = cache.distance(from: position, to: node.position)
            if nodeDistance > snapDistance * 3 { continue } // Быстрая отсечка
            
            // Проверяем input порты
            for port in node.inputPorts {
                let portPosition = cache.getCachedPortPosition(node: node, port: port)
                let dist = cache.distance(from: position, to: portPosition)
                
                if dist < closestDistance {
                    closestDistance = dist
                    closestNode = node
                    closestPort = port
                }
            }
            
            // Проверяем output порты
            for port in node.outputPorts {
                let portPosition = cache.getCachedPortPosition(node: node, port: port)
                let dist = cache.distance(from: position, to: portPosition)
                
                if dist < closestDistance {
                    closestDistance = dist
                    closestNode = node
                    closestPort = port
                }
            }
        }
        
        return (closestNode, closestPort)
    }
    
    // MARK: - Connection Rendering Helpers
    
    func hasActiveConnection() -> Bool {
        return connectionDragFromPosition != nil && connectionDragCurrentPosition != nil
    }
    
    func getPreviewConnectionPoints() -> (CGPoint, CGPoint)? {
        guard let from = connectionDragFromPosition,
              let to = connectionDragCurrentPosition else {
            return nil
        }
        return (from, to)
    }
} 