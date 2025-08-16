//
//  NodeView.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 14.07.2025.
//

import SwiftUI

struct NodeView: View {
    @ObservedObject var node: BaseNode
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    let onStartConnection: ((UUID, UUID, CGPoint) -> Void)?
    let onEndConnection: ((UUID, UUID) -> Void)?
    let onConnectionDrag: ((UUID, UUID, CGPoint) -> Void)?
    let onMove: ((CGPoint) -> Void)?
    let onMoveRealtime: ((CGPoint) -> Void)?
    
    @State private var scale: CGFloat = 1.0
    
    // Блокировка перетаскивания ноды во время создания соединения
    @State private var isConnecting: Bool = false
    @State private var connectionTimeoutTimer: Timer?
    
    // Add state for drag start position
    @State private var dragStartPosition: CGPoint?
    
    var body: some View {
        ZStack {
            // Check if this is an InputNode and show specialized view
            if let inputNode = node as? InputNode {
                InputNodeBodyView(
                    inputNode: inputNode,
                    isSelected: isSelected,
                    onSelect: onSelect,
                    onDelete: onDelete
                )
            } else {
                nodeBodyView
            }
            
            inputPortsView
            outputPortsView
        }
        .scaleEffect(1.0)
        .gesture(
            DragGesture(coordinateSpace: .named("NodeGraphPanel"))
                .onChanged { value in
                    // Блокируем перетаскивание ноды во время создания соединения
                    if !isConnecting {
                        if dragStartPosition == nil {
                            dragStartPosition = node.position
                        }
                        let newPosition = CGPoint(
                            x: dragStartPosition!.x + value.translation.width,
                            y: dragStartPosition!.y + value.translation.height
                        )
                        node.position = newPosition
                        
                        // Обновляем позицию в реальном времени для связей
                        onMoveRealtime?(newPosition)
                    }
                }
                .onEnded { value in
                    // Перемещаем ноду только если не было создания соединения
                    if !isConnecting {
                        let newPosition = CGPoint(
                            x: dragStartPosition!.x + value.translation.width,
                            y: dragStartPosition!.y + value.translation.height
                        )
                        onMove?(newPosition)
                    }
                    dragStartPosition = nil
                }
        )
        .position(node.position)
        .onAppear {
            // Подписываемся на уведомления об отмене операций подключения
            NotificationCenter.default.addObserver(
                forName: .cancelAllConnections,
                object: nil,
                queue: .main
            ) { _ in
                resetConnectionState()
            }
        }
        .onDisappear {
            // Отписываемся от уведомлений и сбрасываем состояние
            NotificationCenter.default.removeObserver(self, name: .cancelAllConnections, object: nil)
            resetConnectionState()
        }
        // Убрана анимация появления
    }
    
    // Функция для принудительного сброса состояния подключения
    private func resetConnectionState() {
        isConnecting = false
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
    }
    
    // Функция для установки таймаута на операцию подключения
    private func startConnectionTimeout() {
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
            // Принудительно сбрасываем состояние через 10 секунд
            resetConnectionState()
        }
    }
    
    private var nodeBodyView: some View {
        HStack {
            RoundedRectangle(cornerRadius: NodeViewConstants.nodeCornerRadius)
                .fill(nodeBackgroundColor)
                .frame(width: NodeViewConstants.nodeWidth, height: NodeViewConstants.nodeHeight)
                .overlay(
                    VStack(spacing: 4) {
                        Text(node.title)
                            .font(.caption)
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: NodeViewConstants.nodeCornerRadius)
                        .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: NodeViewConstants.selectionBorderWidth)
                )
                .onTapGesture {
                    onSelect()
                }
        }
    }
    
    private var nodeBackgroundColor: Color {
        return Color.gray.opacity(0.8)
    }
    
    private var inputPortsView: some View {
        ForEach(Array(node.inputPorts.enumerated()), id: \.element.id) { index, port in
            let portPosition = NodeViewConstants.inputPortPosition(
                at: CGPoint.zero, // Relative to node center
                portIndex: index,
                totalPorts: node.inputPorts.count
            )
            
            NodePortView(
                port: port,
                isConnected: node.inputConnections.contains { $0.toNode == node.id && $0.toPort == port.id },
                nodeID: node.id,
                onStartConnection: { nodeID, portID, pos in
                    isConnecting = true
                    startConnectionTimeout()
                    onStartConnection?(nodeID, portID, pos)
                },
                onEndConnection: { nodeID, portID in
                    resetConnectionState()
                    onEndConnection?(nodeID, portID)
                },
                onConnectionDrag: onConnectionDrag
            )
            .frame(width: NodeViewConstants.portSize, height: NodeViewConstants.portSize)
            .offset(x: portPosition.x, y: portPosition.y)
        }
    }
    
    private var outputPortsView: some View {
        ForEach(Array(node.outputPorts.enumerated()), id: \.element.id) { index, port in
            let portPosition = NodeViewConstants.outputPortPosition(
                at: CGPoint.zero, // Relative to node center
                portIndex: index,
                totalPorts: node.outputPorts.count
            )
            
            NodePortView(
                port: port,
                isConnected: node.outputConnections.contains { $0.fromNode == node.id && $0.fromPort == port.id },
                nodeID: node.id,
                onStartConnection: { nodeID, portID, pos in
                    isConnecting = true
                    startConnectionTimeout()
                    onStartConnection?(nodeID, portID, pos)
                },
                onEndConnection: { nodeID, portID in
                    resetConnectionState()
                    onEndConnection?(nodeID, portID)
                },
                onConnectionDrag: onConnectionDrag
            )
            .frame(width: NodeViewConstants.portSize, height: NodeViewConstants.portSize)
            .offset(x: portPosition.x, y: portPosition.y)
        }
    }
}

// MARK: - Specialized Input Node View

struct InputNodeBodyView: View {
    @ObservedObject var inputNode: InputNode
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    

    
    var body: some View {
        VStack(spacing: 0) {
            // Main node body
            RoundedRectangle(cornerRadius: NodeViewConstants.nodeCornerRadius)
                .fill(nodeBackgroundColor)
                .frame(width: NodeViewConstants.nodeWidth, height: NodeViewConstants.nodeHeight)
                .overlay(
                    VStack(spacing: 4) {
                        // Node title and file info
                        VStack(spacing: 2) {
                            Text(inputNode.title)
                                .font(.caption)
                                .foregroundColor(.white)
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            if let fileSize = inputNode.fileSize {
                                Text(fileSize)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: NodeViewConstants.nodeCornerRadius)
                        .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: NodeViewConstants.selectionBorderWidth)
                )
                .onTapGesture {
                    onSelect()
                }
        }
    }
    
    // MARK: - Helper Properties
    
    private var nodeBackgroundColor: Color {
        switch inputNode.mediaType {
        case .image:
            return Color.blue.opacity(0.6)
        case .video:
            return Color.purple.opacity(0.6)
        }
    }
    
    private var mediaTypeColor: Color {
        switch inputNode.mediaType {
        case .image:
            return .cyan
        case .video:
            return .purple
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct NodePortView: View {
    let port: NodePort
    let isConnected: Bool
    let nodeID: UUID
    let onStartConnection: ((UUID, UUID, CGPoint) -> Void)? // nodeID, portID, pos
    let onEndConnection: ((UUID, UUID) -> Void)? // nodeID, portID
    let onConnectionDrag: ((UUID, UUID, CGPoint) -> Void)? // nodeID, portID, pos
    
    @GestureState private var isDragging = false
    @State private var hasStarted = false // Предотвращает множественные вызовы onStartConnection
    
    var body: some View {
        portShape
            .frame(width: 10, height: 10)
            .highPriorityGesture(
                DragGesture(coordinateSpace: .named("NodeGraphPanel"))
                    .updating($isDragging) { value, state, _ in
                        state = true
                    }
                    .onChanged { value in
                        if !hasStarted {
                            hasStarted = true
                            onStartConnection?(nodeID, port.id, value.startLocation)
                        }
                        onConnectionDrag?(nodeID, port.id, value.location)
                    }
                    .onEnded { value in
                        // Всегда сбрасываем состояние при завершении gesture
                        hasStarted = false
                        onEndConnection?(nodeID, port.id)
                    }
            )
            .onChange(of: isDragging) { oldValue, newValue in
                // Дополнительная защита: если dragging прекратился, но hasStarted все еще true
                if !newValue && hasStarted {
                    hasStarted = false
                    onEndConnection?(nodeID, port.id)
                }
            }
    }
    
    private var portBorderColor: Color {
        return portDataTypeColor
    }
    
    private var portDataTypeColor: Color {
        switch port.dataType {
        case .image:
            return .blue
        case .mask:
            return .red
        case .value:
            return .green
        }
    }
    
    private var portColor: Color {
        if isConnected {
            return portDataTypeColor.opacity(0.8)
        } else {
            return portDataTypeColor.opacity(0.4)
        }
    }
    
    @ViewBuilder
    private var portShape: some View {
        switch port.type {
        case .input:
            Rectangle()
                .fill(portColor)
        case .output:
            TriangleDownShape()
                .fill(portColor)
                .frame(width: 12, height: 12)
        }
    }
}

// MARK: - Custom Port Shapes

struct TriangleDownShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Треугольник направленный вниз
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))      // Нижняя вершина
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))   // Левый верхний угол
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))   // Правый верхний угол
        path.closeSubpath()
        
        return path
    }
}

#Preview {
    NodeView(
        node: InputNode(position: CGPoint(x: 100, y: 100)),
        isSelected: false,
        onSelect: {},
        onDelete: {},
        onStartConnection: nil,
        onEndConnection: nil,
        onConnectionDrag: nil,
        onMove: nil,
        onMoveRealtime: nil
    )
}
