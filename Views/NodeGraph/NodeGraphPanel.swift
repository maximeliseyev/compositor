//
//  NodeGraphPanel.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 14.07.2025.
//

import SwiftUI
import AppKit

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
    @State private var connectionValidationResult: ConnectionValidationResult = .valid
    
    @State private var panelSize: CGSize = .zero
    
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
            // NodePanelMouseView at the bottom for right-click context menu
            NodePanelMouseView { nodeType, location in
                createNode(ofType: nodeType, at: location)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(true)
            .background(Color.clear)
            
            NodePanelKeyHandler(onDelete: deleteSelectedNodes)
            
            // Grid background
            gridBackground
            
            // Panel background
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedNodes.removeAll()
                    selectedNode = nil
                    resetConnectionDrag()
                }
        }
    }
    
    private var gridBackground: some View {
        Canvas { context, size in
            drawGrid(context: context, size: size)
        }
    }
    
    private func nodeViewsLayer(geometry: GeometryProxy) -> some View {
        ForEach(nodeGraph.nodes, id: \.id) { node in
            createNodeView(for: node, geometry: geometry)
        }
    }
    
    private var connectionsLayer: some View {
        ZStack {
            // Render all connections
            ForEach(nodeGraph.connections, id: \.id) { connection in
                createConnectionPath(for: connection)
            }
        }
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
            if connectionValidationResult != .valid,
               let currentPos = connectionDragCurrentPosition {
                createConnectionFeedback(at: currentPos)
            }
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
            onStartConnection: { fromNodeID, portPosition in
                // Port position is in NodeGraphPanel coordinate space
                startPortConnection(fromNodeID: fromNodeID, portPosition: portPosition)
            },
            onEndConnection: { toNodeID in
                endPortConnection(toNodeID: toNodeID)
            },
            onConnectionDrag: { pos in
                // Position is in NodeGraphPanel coordinate space
                updateConnectionDrag(to: pos)
            },
            onMove: { newPosition in
                nodeGraph.moveNode(node, to: newPosition)
            }
        )
    }
    
    private func createConnectionPath(for connection: NodeConnection) -> some View {
        Group {
            if let fromNode = nodeGraph.nodes.first(where: { $0.id == connection.fromNode }),
               let toNode = nodeGraph.nodes.first(where: { $0.id == connection.toNode }) {
                
                let (fromPoint, toPoint) = getConnectionPoints(for: connection, fromNode: fromNode, toNode: toNode)
                
                createBezierConnection(from: fromPoint, to: toPoint, isValid: true)
            } else {
                // Return an invisible connection instead of EmptyView
                createBezierConnection(from: CGPoint.zero, to: CGPoint.zero, isValid: false)
                    .opacity(0)
            }
        }
    }
    
    private func createPreviewConnection(from: CGPoint, to: CGPoint) -> some View {
        createBezierConnection(from: from, to: to, isValid: connectionValidationResult == .valid)
    }
    
    private func createBezierConnection(from: CGPoint, to: CGPoint, isValid: Bool) -> some View {
        // Use vertical control points for top-to-bottom flow
        let controlPoint1 = CGPoint(x: from.x, y: from.y + 50)
        let controlPoint2 = CGPoint(x: to.x, y: to.y - 50)
        
        return Path { path in
            path.move(to: from)
            path.addCurve(to: to, control1: controlPoint1, control2: controlPoint2)
        }
        .stroke(
            isValid ? Color.orange : Color.red,
            style: StrokeStyle(lineWidth: NodeConstants.connectionLineWidth, lineCap: .round)
        )
        .opacity(isValid ? 1.0 : 0.6)
    }
    
    private func createSelectionRectangle(rect: CGRect) -> some View {
        Rectangle()
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1, dash: [5]))
            .background(Rectangle().fill(Color.accentColor.opacity(0.15)))
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .allowsHitTesting(false)
    }
    
    private func createConnectionFeedback(at position: CGPoint) -> some View {
        VStack {
            Text("⚠️")
                .font(.title2)
            Text(connectionValidationResult.errorMessage)
                .font(.caption)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
        }
        .padding(8)
        .background(Color.black.opacity(0.8))
        .cornerRadius(8)
        .position(position)
    }
    
    // MARK: - Connection Management
    
    private func startPortConnection(fromNodeID: UUID, portPosition: CGPoint) {
        guard let fromNode = nodeGraph.nodes.first(where: { $0.id == fromNodeID }) else { return }
        guard let fromPort = fromNode.outputPorts.first else { return }
        
        connectionDragFromNodeID = fromNodeID
        connectionDragFromPortID = fromPort.id
        connectionDragFromPosition = portPosition
        connectionDragCurrentPosition = portPosition
        connectionDragToNodeID = nil
        connectionDragToPortID = nil
        connectionValidationResult = .valid
    }
    
    private func updateConnectionDrag(to position: CGPoint) {
        connectionDragCurrentPosition = position
        
        // Check if we're over a valid target
        let (targetNode, targetPort) = findTargetAtPosition(position)
        if let targetNode = targetNode, let targetPort = targetPort {
            connectionDragToNodeID = targetNode.id
            connectionDragToPortID = targetPort.id
            
            // Validate the connection
            if let fromNode = nodeGraph.nodes.first(where: { $0.id == connectionDragFromNodeID }),
               let fromPort = fromNode.outputPorts.first(where: { $0.id == connectionDragFromPortID }) {
                connectionValidationResult = nodeGraph.validateConnection(fromNode: fromNode, fromPort: fromPort, toNode: targetNode, toPort: targetPort)
            }
        } else {
            connectionDragToNodeID = nil
            connectionDragToPortID = nil
            connectionValidationResult = .valid
        }
    }
    
    private func resetConnectionDrag() {
        connectionDragFromNodeID = nil
        connectionDragFromPortID = nil
        connectionDragFromPosition = nil
        connectionDragCurrentPosition = nil
        connectionDragToNodeID = nil
        connectionDragToPortID = nil
        connectionValidationResult = .valid
    }
    
    private func endPortConnection(toNodeID: UUID) {
        guard let fromNodeID = connectionDragFromNodeID,
              let fromNode = nodeGraph.nodes.first(where: { $0.id == fromNodeID }),
              let toNode = nodeGraph.nodes.first(where: { $0.id == toNodeID }) else {
            resetConnectionDrag()
            return
        }
        
        // Find the first available input port on the target node
        guard let toPort = toNode.inputPorts.first else {
            resetConnectionDrag()
            return
        }
        
        guard let fromPort = fromNode.outputPorts.first else {
            resetConnectionDrag()
            return
        }
        
        // Attempt to connect
        _ = nodeGraph.connectPorts(fromNode: fromNode, fromPort: fromPort, toNode: toNode, toPort: toPort)
        
        resetConnectionDrag()
    }
    
    // MARK: - Helper Methods for Port Finding
    
    private func findTargetAtPosition(_ position: CGPoint) -> (BaseNode?, NodePort?) {
        for node in nodeGraph.nodes {
            if isPointInNode(position, node: node) {
                return (node, node.inputPorts.first)
            }
        }
        return (nil, nil)
    }
    
    private func isPointInNode(_ point: CGPoint, node: BaseNode) -> Bool {
        let nodeFrame = NodeConstants.nodeHitFrame(at: node.position)
        return nodeFrame.contains(point)
    }
    
    private func getPortWorldPosition(node: BaseNode, port: NodePort) -> CGPoint {
        return port.type == .input ? 
            NodeConstants.inputPortPosition(at: node.position) :
            NodeConstants.outputPortPosition(at: node.position)
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
        case .input:
            let inputNode = InputNode(position: position)
            nodeGraph.addNode(inputNode)
        case .corrector:
            let correctorNode = CorrectorNode(position: position)
            nodeGraph.addNode(correctorNode)
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

// MARK: - Supporting Views (unchanged)

struct NodePanelMouseView: NSViewRepresentable {
    var onCreateNode: (NodeType, CGPoint) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = RightClickOnlyView()
        let gesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleClick(_:)))
        gesture.buttonMask = 0x2 // Right mouse button
        view.addGestureRecognizer(gesture)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCreateNode: onCreateNode)
    }

    class Coordinator: NSObject, NSMenuDelegate {
        var onCreateNode: (NodeType, CGPoint) -> Void

        init(onCreateNode: @escaping (NodeType, CGPoint) -> Void) {
            self.onCreateNode = onCreateNode
        }

        @objc func handleClick(_ sender: NSClickGestureRecognizer) {
            guard let view = sender.view else { return }
            let location = sender.location(in: view)
            let menu = NSMenu()
            
            for type in NodeType.allCases {
                let item = NSMenuItem(title: "Create \(type.rawValue) Node", action: #selector(menuItemSelected(_:)), keyEquivalent: "")
                item.representedObject = type.rawValue
                item.target = self
                menu.addItem(item)
            }
            
            menu.delegate = self
            objc_setAssociatedObject(menu, &Coordinator.menuLocationKey, NSValue(point: location), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            NSMenu.popUpContextMenu(menu, with: NSApp.currentEvent!, for: view)
        }

        @objc func menuItemSelected(_ sender: NSMenuItem) {
            guard let menu = sender.menu,
                  let value = objc_getAssociatedObject(menu, &Coordinator.menuLocationKey) as? NSValue,
                  let typeRaw = sender.representedObject as? String,
                  let type = NodeType(rawValue: typeRaw) else { return }
            
            let location = value.pointValue
            onCreateNode(type, location)
        }

        static var menuLocationKey: UInt8 = 0
    }
    
    class RightClickOnlyView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? {
            // Only respond to right-clicks, let everything else pass through
            if let event = NSApp.currentEvent {
                if event.type == .rightMouseDown || (event.type == .otherMouseDown && event.buttonNumber == 2) {
                    return super.hitTest(point)
                }
            }
            return nil
        }
    }
}

struct NodePanelKeyHandler: NSViewRepresentable {
    var onDelete: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = KeyCatcherView()
        view.onDelete = onDelete
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    class KeyCatcherView: NSView {
        var onDelete: (() -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            if event.keyCode == 51 || event.keyCode == 117 { // 51 = delete, 117 = forward delete
                onDelete?()
            } else {
                super.keyDown(with: event)
            }
        }

        override func viewDidMoveToWindow() {
            window?.makeFirstResponder(self)
        }
    }
}
