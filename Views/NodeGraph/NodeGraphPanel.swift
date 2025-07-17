//
//  NodeGraphPanel.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 14.07.2025.
//

import SwiftUI
import AppKit
import Foundation

// MARK: - Imports для Core типов
// Эти импорты позволят использовать все типы из Core модуля
// В будущем можно будет заменить на @import Core при модулярной архитектуре

// MARK: - Extensions
// Notification names определены в Core/Graph/NotificationNames.swift

// MARK: - Node Graph Renderer Protocol
// Архитектура готова для Metal интеграции:
// 1. Протокол NodeGraphRenderer позволяет легко заменить Canvas на Metal
// 2. Все типы определены явно для эффективного GPU рендеринга
// 3. Модульная структура позволяет создать MetalNodeGraphRenderer
protocol NodeGraphRenderer {
    func renderConnections(connections: [NodeConnection], nodes: [BaseNode], getConnectionPoints: @escaping (NodeConnection, BaseNode, BaseNode) -> (CGPoint, CGPoint)) -> AnyView
}

// MARK: - Canvas Implementation (Временное решение)
// Для больших графов (10к+ нод) будет заменено на MetalNodeGraphRenderer
struct CanvasNodeGraphRenderer: NodeGraphRenderer {
    func renderConnections(connections: [NodeConnection], nodes: [BaseNode], getConnectionPoints: @escaping (NodeConnection, BaseNode, BaseNode) -> (CGPoint, CGPoint)) -> AnyView {
        AnyView(
            Canvas { context, size in
                for connection in connections {
                    guard let fromNode = nodes.first(where: { $0.id == connection.fromNode }),
                          let toNode = nodes.first(where: { $0.id == connection.toNode }) else { continue }
                    let (fromPoint, toPoint) = getConnectionPoints(connection, fromNode, toNode)
                    var path = Path()
                    path.move(to: fromPoint)
                    path.addLine(to: toPoint)
                    context.stroke(path, with: .color(.white), lineWidth: 1)
                }
            }
            .allowsHitTesting(false)
        )
    }
}

struct NodeGraphPanel: View {
    @StateObject private var nodeGraph = NodeGraph()
    @ObservedObject var viewerController: ViewerPanelController
    @State private var selectedNode: BaseNode?
    @State private var selectedNodes: Set<UUID> = []
    @State private var selectionRect: CGRect? = nil
    @State private var isSelecting: Bool = false
    
    // Port connection states
    @State private var connectionDragFromNodeID: UUID? = nil
    @State private var connectionDragFromPortID: UUID? = nil
    @State private var connectionDragFromPosition: CGPoint? = nil
    @State private var connectionDragCurrentPosition: CGPoint? = nil
    @State private var connectionDragToNodeID: UUID? = nil
    @State private var connectionDragToPortID: UUID? = nil
    
    @State private var panelSize: CGSize = .zero
    @State private var lastPreviewUpdateTime: TimeInterval = 0
    
    // Renderer для связей - можно переключить на Metal для производительности
    // TODO: Добавить логику выбора рендерера в зависимости от количества нод
    private let renderer: NodeGraphRenderer = CanvasNodeGraphRenderer()
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                backgroundLayers
                nodeViewsLayer(geometry: geo)
                connectionsLayer
                previewConnectionLayer
                selectionRectangleLayer
                connectionFeedbackLayer
            }
            .background(Color.clear)
            .coordinateSpace(name: "NodeGraphPanel")
            .onAppear {
                setupNotifications(geometry: geo)
            }
            .onDisappear {
                removeNotifications()
            }
        }
        .gesture(selectionGesture)
        .clipped()
        .border(Color.gray.opacity(0.3), width: 1)
    }
    
    // MARK: - Computed Properties for UI Layers
    
    private var backgroundLayers: some View {
        ZStack {
            // Grid background
            gridBackground
            
            // Panel background
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .allowsHitTesting(false)
            
            // Combined mouse and key handler
            NodePanelEventHandler(
                onCreateNode: { nodeType, location in
                    createNode(ofType: nodeType, at: location)
                },
                onDelete: deleteSelectedNodes,
                onDeselectAll: {
                    selectedNodes.removeAll()
                    selectedNode = nil
                    resetConnectionDrag()
                    // Уведомляем все ноды о необходимости сброса состояния подключения
                    NotificationCenter.default.post(name: .cancelAllConnections, object: nil)
                }
            )
            .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity)
            .allowsHitTesting(true)
            .background(Color.clear)
        }
    }
    
    private var gridBackground: some View {
        Canvas { context, size in
            drawGrid(context: context, size: size)
        }
    }
    
    private func nodeViewsLayer(geometry: GeometryProxy) -> some View {
        ForEach(nodeGraph.nodes, id: \.id) { (node: BaseNode) in
            createNodeView(for: node, geometry: geometry)
        }
    }
    
    private var connectionsLayer: some View {
        renderer.renderConnections(
            connections: nodeGraph.connections,
            nodes: nodeGraph.nodes,
            getConnectionPoints: { connection, fromNode, toNode in
                getConnectionPoints(for: connection, fromNode: fromNode, toNode: toNode)
            }
        )
    }
    
    private var previewConnectionLayer: some View {
        Group {
            if let from = connectionDragFromPosition,
               let to = connectionDragCurrentPosition {
                createPreviewConnection(from: from, to: to)
            }
        }
    }
    
    private var selectionRectangleLayer: some View {
        Group {
            if let rect = selectionRect, isSelecting {
                createSelectionRectangle(rect: rect)
            }
        }
    }
    
    private var connectionFeedbackLayer: some View {
        Group {
            // Убираем отображение ошибок соединения
        }
    }
    
    private var selectionGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                if connectionDragFromNodeID == nil {
                    handleSelectionDrag(value: value)
                }
            }
            .onEnded { _ in
                endSelection()
            }
    }
    
    // MARK: - Helper Methods for UI Creation
    
    private func createNodeView(for node: BaseNode, geometry: GeometryProxy) -> some View {
        NodeView(
            node: node,
            isSelected: selectedNodes.contains(node.id),
            onSelect: {
                selectedNode = node
                selectedNodes = [node.id]
                resetConnectionDrag()
            },
            onDelete: { deleteNode(node) },
            onStartConnection: { fromNodeID, fromPortID, panelPos in
                startPortConnection(fromNodeID: fromNodeID, fromPortID: fromPortID, portPosition: panelPos)
            },
            onEndConnection: { toNodeID, toPortID in
                endPortConnection(toNodeID: toNodeID, toPortID: toPortID)
            },
            onConnectionDrag: { _, _, pos in
                updateConnectionDrag(to: pos)
            },
            onMove: { newPosition in
                nodeGraph.moveNode(node, to: newPosition)
            }
        )
    }
    
    // MARK: - Connection path creation removed - using renderer.renderConnections instead
    
    private func createPreviewConnection(from: CGPoint, to: CGPoint) -> some View {
        Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }
        .stroke(Color.white, lineWidth: 2)
    }
    
    private func createSelectionRectangle(rect: CGRect) -> some View {
        Rectangle()
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1, dash: [5]))
            .background(Rectangle().fill(Color.accentColor.opacity(0.15)))
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .allowsHitTesting(false)
    }
    

    
    // MARK: - Connection Management
    
    private func startPortConnection(fromNodeID: UUID, fromPortID: UUID, portPosition: CGPoint) {
        print("Starting connection from node: \(fromNodeID), port: \(fromPortID), position: \(portPosition)")
        connectionDragFromNodeID = fromNodeID
        connectionDragFromPortID = fromPortID
        connectionDragFromPosition = portPosition
        connectionDragCurrentPosition = portPosition
        connectionDragToNodeID = nil
        connectionDragToPortID = nil
    }
    
    private func updateConnectionDrag(to position: CGPoint) {
        let now = CACurrentMediaTime()
        if now - lastPreviewUpdateTime < 0.016 { return }
        lastPreviewUpdateTime = now
        
        // Всегда следуем за курсором
        connectionDragCurrentPosition = position
        
        // Check if we're over a valid target for potential connection
        let (targetNode, targetPort) = findTargetAtPosition(position)
        connectionDragToNodeID = targetNode?.id
        connectionDragToPortID = targetPort?.id
    }
    
    private func resetConnectionDrag() {
        connectionDragFromNodeID = nil
        connectionDragFromPortID = nil
        connectionDragFromPosition = nil
        connectionDragCurrentPosition = nil
        connectionDragToNodeID = nil
        connectionDragToPortID = nil
    }
    
    private func endPortConnection(toNodeID: UUID, toPortID: UUID) {
        print("Ending connection at node: \(toNodeID), port: \(toPortID)")
        print("Target found: node=\(connectionDragToNodeID?.uuidString ?? "nil"), port=\(connectionDragToPortID?.uuidString ?? "nil")")
        
        // Завершаем соединение - проверяем есть ли валидная цель
        if let targetNodeID = connectionDragToNodeID,
           let targetPortID = connectionDragToPortID,
           let fromNodeID = connectionDragFromNodeID,
           let fromPortID = connectionDragFromPortID,
           let fromNode = nodeGraph.nodes.first(where: { $0.id == fromNodeID }),
           let toNode = nodeGraph.nodes.first(where: { $0.id == targetNodeID }),
           let fromPort = (fromNode.inputPorts + fromNode.outputPorts).first(where: { $0.id == fromPortID }),
           let toPort = (toNode.inputPorts + toNode.outputPorts).first(where: { $0.id == targetPortID }) {
            
            print("Creating connection: \(fromNode.title).\(fromPort.name) -> \(toNode.title).\(toPort.name)")
            
            // Создаем соединение только если типы портов совместимы
            if fromPort.type == NodePortType.output && toPort.type == NodePortType.input {
                let success = nodeGraph.connectPorts(fromNode: fromNode, fromPort: fromPort, toNode: toNode, toPort: toPort)
                print("Connection result: \(success)")
            } else if fromPort.type == NodePortType.input && toPort.type == NodePortType.output {
                let success = nodeGraph.connectPorts(fromNode: toNode, fromPort: toPort, toNode: fromNode, toPort: fromPort)
                print("Connection result: \(success)")
            } else {
                print("Port types incompatible: \(fromPort.type) -> \(toPort.type)")
            }
        } else {
            print("Failed to create connection - missing components")
        }
        
        resetConnectionDrag()
    }
    
    // MARK: - Helper Methods for Port Finding
    
    private func findTargetAtPosition(_ position: CGPoint) -> (BaseNode?, NodePort?) {
        let snapDistance: CGFloat = 20 // Расстояние для "прилипания" к порту
        var closestNode: BaseNode? = nil
        var closestPort: NodePort? = nil
        var closestDistance: CGFloat = snapDistance
        
        for node in nodeGraph.nodes {
            // Проверяем input ports
            for port in node.inputPorts {
                let portPosition = getPortWorldPosition(node: node, port: port)
                let distance = sqrt(pow(position.x - portPosition.x, 2) + pow(position.y - portPosition.y, 2))
                
                if distance < closestDistance {
                    closestDistance = distance
                    closestNode = node
                    closestPort = port
                }
            }
            
            // Проверяем output ports
            for port in node.outputPorts {
                let portPosition = getPortWorldPosition(node: node, port: port)
                let distance = sqrt(pow(position.x - portPosition.x, 2) + pow(position.y - portPosition.y, 2))
                
                if distance < closestDistance {
                    closestDistance = distance
                    closestNode = node
                    closestPort = port
                }
            }
        }
        
        return (closestNode, closestPort)
    }
    
    private func isPointInNode(_ point: CGPoint, node: BaseNode) -> Bool {
        let nodeFrame = NodeConstants.nodeHitFrame(at: node.position)
        return nodeFrame.contains(point)
    }
    
    private func getPortWorldPosition(node: BaseNode, port: NodePort) -> CGPoint {
        if port.type == NodePortType.input {
            guard let portIndex = node.inputPorts.firstIndex(where: { $0.id == port.id }) else {
                return NodeConstants.inputPortPosition(at: node.position)
            }
            return NodeConstants.inputPortPosition(
                at: node.position,
                portIndex: portIndex,
                totalPorts: node.inputPorts.count
            )
        } else {
            guard let portIndex = node.outputPorts.firstIndex(where: { $0.id == port.id }) else {
                return NodeConstants.outputPortPosition(at: node.position)
            }
            return NodeConstants.outputPortPosition(
                at: node.position,
                portIndex: portIndex,
                totalPorts: node.outputPorts.count
            )
        }
    }
    
    private func getConnectionPoints(for connection: NodeConnection, fromNode: BaseNode, toNode: BaseNode) -> (CGPoint, CGPoint) {
        let fromPoint: CGPoint
        let toPoint: CGPoint
        
        if let fromPort = fromNode.outputPorts.first(where: { $0.id == connection.fromPort }) {
            fromPoint = getPortWorldPosition(node: fromNode, port: fromPort)
        } else {
            fromPoint = CGPoint(x: fromNode.position.x, y: fromNode.position.y + 30)
        }
        
        if let toPort = toNode.inputPorts.first(where: { $0.id == connection.toPort }) {
            toPoint = getPortWorldPosition(node: toNode, port: toPort)
        } else {
            toPoint = CGPoint(x: toNode.position.x, y: toNode.position.y - 30)
        }
        
        return (fromPoint, toPoint)
    }
    
    // MARK: - Grid and Selection Logic (unchanged)
    
    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let gridSpacing = NodeConstants.gridSpacing
        let lineColor = Color.gray.opacity(0.2)
        
        // Vertical lines
        var x: CGFloat = 0
        while x <= size.width {
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(path, with: .color(lineColor), lineWidth: 1)
            x += gridSpacing
        }
        
        // Horizontal lines
        var y: CGFloat = 0
        while y <= size.height {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(lineColor), lineWidth: 1)
            y += gridSpacing
        }
    }
    
    private func handleSelectionDrag(value: DragGesture.Value) {
        isSelecting = true
        let start = value.startLocation
        let current = value.location
        
        let rect = CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
        
        selectionRect = rect
        
        let selectedNodeIds = nodeGraph.nodes
            .filter { node in rect.contains(node.position) }
            .map { $0.id }
        
        selectedNodes = Set(selectedNodeIds)
    }
    
    private func endSelection() {
        isSelecting = false
        selectionRect = nil
    }
    
    // MARK: - Node Management (unchanged)
    
    private func setupNotifications(geometry: GeometryProxy) {
        panelSize = geometry.size
        NotificationCenter.default.addObserver(
            forName: .createNodeFromMenu,
            object: nil,
            queue: .main
        ) { notification in
            handleCreateNodeNotification(notification: notification, geometry: geometry)
        }
    }
    
    private func handleCreateNodeNotification(notification: Notification, geometry: GeometryProxy) {
        if let type = notification.object as? NodeType {
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            createNode(ofType: type, at: center)
        }
    }
    
    private func removeNotifications() {
        NotificationCenter.default.removeObserver(self, name: .createNodeFromMenu, object: nil)
    }
    
    private func createNode(ofType type: NodeType, at position: CGPoint) {
        switch type {
        case .view:
            let viewerNode = ViewNode(position: position, viewerPanel: viewerController)
            nodeGraph.addNode(viewerNode)
            // Auto-select the newly created node
            selectedNode = viewerNode
            selectedNodes = [viewerNode.id]
        case .input:
            let inputNode = InputNode(position: position)
            nodeGraph.addNode(inputNode)
            selectedNode = inputNode
            selectedNodes = [inputNode.id]
        case .corrector:
            let correctorNode = CorrectorNode(position: position)
            nodeGraph.addNode(correctorNode)
            selectedNode = correctorNode
            selectedNodes = [correctorNode.id]
        }
    }

    private func deleteNode(_ node: BaseNode) {
        nodeGraph.removeNode(node)
        if selectedNode?.id == node.id {
            selectedNode = nil
        }
    }

    private func deleteSelectedNodes() {
        let nodesToDelete = nodeGraph.nodes.filter { selectedNodes.contains($0.id) }
        for node in nodesToDelete {
            nodeGraph.removeNode(node)
        }
        selectedNodes.removeAll()
        selectedNode = nil
    }
}

// MARK: - Supporting Views

struct NodePanelEventHandler: NSViewRepresentable {
    var onCreateNode: (NodeType, CGPoint) -> Void
    var onDelete: () -> Void
    var onDeselectAll: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = EventHandlerView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let view = nsView as! EventHandlerView
        view.coordinator = context.coordinator
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onCreateNode: onCreateNode,
            onDelete: onDelete,
            onDeselectAll: onDeselectAll
        )
    }

    class Coordinator: NSObject, NSMenuDelegate {
        var onCreateNode: (NodeType, CGPoint) -> Void
        var onDelete: () -> Void
        var onDeselectAll: () -> Void

        init(onCreateNode: @escaping (NodeType, CGPoint) -> Void, onDelete: @escaping () -> Void, onDeselectAll: @escaping () -> Void) {
            self.onCreateNode = onCreateNode
            self.onDelete = onDelete
            self.onDeselectAll = onDeselectAll
        }

        func showContextMenu(at point: NSPoint, with event: NSEvent, in view: NSView) {
            let menu = NSMenu()
            
            // Add search field (placeholder for now)
            let searchItem = NSMenuItem()
            let searchField = NSSearchField()
            searchField.frame = NSRect(x: 0, y: 0, width: 200, height: 20)
            searchField.placeholderString = "Search nodes..."
            searchField.isEnabled = false // Disable for now, will implement search later
            searchItem.view = searchField
            menu.addItem(searchItem)
            menu.addItem(NSMenuItem.separator())
            
            // Group nodes by category
            let categories = NodeCategory.allCases
            for (index, category) in categories.enumerated() {
                let nodesInCategory = NodeType.allCases.filter { $0.category == category }
                
                if !nodesInCategory.isEmpty {
                    // Add category header
                    let categoryItem = NSMenuItem(title: category.displayName, action: nil, keyEquivalent: "")
                    categoryItem.isEnabled = false
                    let font = NSFont.systemFont(ofSize: 10, weight: .medium)
                    categoryItem.attributedTitle = NSAttributedString(
                        string: category.displayName,
                        attributes: [
                            .font: font,
                            .foregroundColor: NSColor.secondaryLabelColor
                        ]
                    )
                    menu.addItem(categoryItem)
                    
                    for nodeType in nodesInCategory {
                        let item = NSMenuItem(
                            title: nodeType.displayName,
                            action: #selector(menuItemSelected(_:)),
                            keyEquivalent: ""
                        )
                        item.representedObject = nodeType.rawValue
                        item.target = self
                        
                        let attributedTitle = NSAttributedString(
                            string: nodeType.displayName,
                            attributes: [
                                .font: NSFont.systemFont(ofSize: 12, weight: .regular)
                            ]
                        )
                        item.attributedTitle = attributedTitle
                        menu.addItem(item)
                    }
                    
                    if index < categories.count - 1 {
                        menu.addItem(NSMenuItem.separator())
                    }
                }
            }
            
            menu.delegate = self
            objc_setAssociatedObject(menu, &Coordinator.menuLocationKey, NSValue(point: point), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            NSMenu.popUpContextMenu(menu, with: event, for: view)
        }

                 @objc func menuItemSelected(_ sender: NSMenuItem) {
            guard let menu = sender.menu,
                  let value = objc_getAssociatedObject(menu, &Coordinator.menuLocationKey) as? NSValue,
                  let typeRaw = sender.representedObject as? String,
                  let type = NodeType(rawValue: typeRaw) else { return }
            
            let location = value.pointValue
            let swiftUIPoint = CGPoint(x: location.x, y: location.y)
            onCreateNode(type, swiftUIPoint)
        }

        static var menuLocationKey: UInt8 = 0
    }
    
    class EventHandlerView: NSView {
        var coordinator: Coordinator?
        
        override func rightMouseDown(with event: NSEvent) {
            let point = convert(event.locationInWindow, from: nil)
            
            coordinator?.showContextMenu(at: point, with: event, in: self)
        }
        
        override func mouseDown(with event: NSEvent) {
            // Handle left click for deselection
            coordinator?.onDeselectAll()
            super.mouseDown(with: event)
        }
        
        override func keyDown(with event: NSEvent) {
            // Delete keys
            if event.keyCode == 51 || event.keyCode == 117 { // 51 = delete, 117 = forward delete
                coordinator?.onDelete()
                return
            }
            
            // Pass all other key events to the next responder
            super.keyDown(with: event)
        }
        
        override var acceptsFirstResponder: Bool {
            return true
        }
        
        override func viewDidMoveToWindow() {
            window?.makeFirstResponder(self)
        }
    }
}


