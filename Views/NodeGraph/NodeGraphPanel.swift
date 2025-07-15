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
    @State private var connectionDragFromNodeID: UUID? = nil
    @State private var connectionDragFromPosition: CGPoint? = nil
    @State private var connectionDragCurrentPosition: CGPoint? = nil
    @State private var panelSize: CGSize = .zero
    
    var body: some View {
        GeometryReader { geo in
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
                Canvas { context, size in
                    let gridSpacing: CGFloat = 40
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
                // Panel background
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedNodes.removeAll()
                        selectedNode = nil
                    }
                
                ForEach(nodeGraph.nodes, id: \.id) { node in
                    NodeView(
                        node: node,
                        isSelected: selectedNodes.contains(node.id),
                        onSelect: {
                            selectedNode = node
                            selectedNodes = [node.id]
                        },
                        onDelete: { deleteNode(node) },
                        onStartConnection: { fromNodeID, portPosition in
                            // Start connection drag from output port
                            connectionDragFromNodeID = fromNodeID
                            // Convert portPosition to global position
                            if let node = nodeGraph.nodes.first(where: { $0.id == fromNodeID }) {
                                let globalPos = node.position
                                connectionDragFromPosition = CGPoint(x: globalPos.x, y: globalPos.y + 30) // 30 = node half height + triangle offset
                            }
                            connectionDragCurrentPosition = connectionDragFromPosition
                        },
                        onEndConnection: { toNodeID in
                            // Complete connection if valid
                            if let fromID = connectionDragFromNodeID,
                               fromID != toNodeID,
                               let fromNode = nodeGraph.nodes.first(where: { $0.id == fromID }),
                               let toNode = nodeGraph.nodes.first(where: { $0.id == toNodeID }) {
                                nodeGraph.connectNodes(from: fromNode, to: toNode)
                            }
                            connectionDragFromNodeID = nil
                            connectionDragFromPosition = nil
                            connectionDragCurrentPosition = nil
                        },
                        onConnectionDrag: { pos in
                            connectionDragCurrentPosition = pos
                        },
                        onMove: { newPosition in
                            nodeGraph.moveNode(node, to: newPosition)
                        }
                    )
                    .position(node.position)
                }
                // Draw all connections
                ForEach(nodeGraph.connections) { connection in
                    if let fromNode = nodeGraph.nodes.first(where: { $0.id == connection.fromNode }),
                       let toNode = nodeGraph.nodes.first(where: { $0.id == connection.toNode }) {
                        Path { path in
                            let from = CGPoint(x: fromNode.position.x, y: fromNode.position.y + 30) // bottom center
                            let to = CGPoint(x: toNode.position.x, y: toNode.position.y - 30) // top center
                            path.move(to: from)
                            path.addLine(to: to)
                        }
                        .stroke(Color.orange, lineWidth: 3)
                    }
                }
                // Draw preview connection
                if let from = connectionDragFromPosition, let to = connectionDragCurrentPosition {
                    Path { path in
                        path.move(to: from)
                        path.addLine(to: to)
                    }
                    .stroke(Color.orange.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [6]))
                }
                // Draw selection rectangle
                if let rect = selectionRect, isSelecting {
                    Rectangle()
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1, dash: [5]))
                        .background(Rectangle().fill(Color.accentColor.opacity(0.15)))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false)
                }
            }
            .onAppear {
                panelSize = geo.size
                NotificationCenter.default.addObserver(forName: .createNodeFromMenu, object: nil, queue: .main) { notif in
                    if let type = notif.object as? NodeType {
                        let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                        createNode(ofType: type, at: center)
                    }
                }
            }
            .onDisappear {
                NotificationCenter.default.removeObserver(self, name: .createNodeFromMenu, object: nil)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
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
                    // Update selected nodes
                    let selected = nodeGraph.nodes.filter { node in
                        rect.contains(node.position)
                    }.map { $0.id }
                    selectedNodes = Set(selected)
                }
                .onEnded { _ in
                    isSelecting = false
                    selectionRect = nil
                }
        )
        .clipped()
        .border(Color.gray.opacity(0.3), width: 1)
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

struct NodePanelMouseView: NSViewRepresentable {
    var onCreateNode: (NodeType, CGPoint) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
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
            if let menu = sender.menu,
               let value = objc_getAssociatedObject(menu, &Coordinator.menuLocationKey) as? NSValue,
               let typeRaw = sender.representedObject as? String,
               let type = NodeType(rawValue: typeRaw) {
                let location = value.pointValue
                onCreateNode(type, location)
            }
        }

        static var menuLocationKey: UInt8 = 0
    }
}

// NSViewRepresentable to intercept keyDown events
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
