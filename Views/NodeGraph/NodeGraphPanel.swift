//
//  NodeGraphPanel.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 14.07.2025.
//

import SwiftUI
import AppKit
import Foundation
import Combine

struct NodeGraphPanel: View {
    @StateObject private var nodeGraph = NodeGraph()
    @ObservedObject var viewerController: ViewerPanelController
    @State private var panelSize: CGSize = .zero
    
    // MARK: - Managers
    @StateObject private var cache = NodeGraphCache()
    @StateObject private var connectionManager = NodeGraphConnectionManager()
    @StateObject private var selectionManager = NodeGraphSelectionManager()
    
    // Cancellables для предотвращения утечек памяти
    @State private var cancellables = Set<AnyCancellable>()
    
    // TODO: Renderer для связей переключить на Metal
    private let renderer: NodeGraphRenderer = CanvasNodeGraphRenderer()
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                backgroundLayers(geometry: geo)
                nodeViewsLayer(geometry: geo)
                connectionsLayer
                previewConnectionLayer
                selectionRectangleLayer
            }
            .background(Color.clear)
            .coordinateSpace(name: "NodeGraphPanel")
            .onAppear {
                setupPanel(geometry: geo)
            }
            .onDisappear {
                cleanupPanel()
            }
            .onChange(of: nodeGraph.nodes.count) { _ in
                cache.updateNodeCache(nodes: nodeGraph.nodes)
            }
        }
        .gesture(selectionGesture)
        .clipped()
        .border(Color.gray.opacity(0.3), width: 1)
    }
    
    // MARK: - Computed Properties for UI Layers
    
    private func backgroundLayers(geometry: GeometryProxy) -> some View {
        ZStack {
            GridBackgroundView(size: geometry.size)
            
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .allowsHitTesting(false)
            
            NodePanelEventHandler(
                onCreateNode: { nodeType, location in
                    createNode(ofType: nodeType, at: location)
                },
                onDelete: {
                    selectionManager.deleteSelectedNodes(nodeGraph: nodeGraph, cache: cache)
                },
                onDeselectAll: {
                    selectionManager.deselectAll()
                    connectionManager.resetConnectionDrag()
                    NotificationCenter.default.post(name: .cancelAllConnections, object: nil)
                }
            )
            .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity)
            .allowsHitTesting(true)
            .background(Color.clear)
        }
    }
    
    private func nodeViewsLayer(geometry: GeometryProxy) -> some View {
        ForEach(nodeGraph.nodes, id: \.id) { node in
            createNodeView(for: node, geometry: geometry)
        }
    }
    
    private var connectionsLayer: some View {
        ZStack {
            ForEach(nodeGraph.connections) { connection in
                if let fromNode = cache.getCachedNode(id: connection.fromNode),
                   let toNode = cache.getCachedNode(id: connection.toNode) {
                    let connectionPoints = cache.getCachedConnectionPoints(
                        for: connection, 
                        fromNode: fromNode, 
                        toNode: toNode
                    )
                    
                    ConnectionLineView(
                        from: connectionPoints.0,
                        to: connectionPoints.1,
                        connectionId: connection.id
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    private var previewConnectionLayer: some View {
        Group {
            if connectionManager.hasActiveConnection(),
               let points = connectionManager.getPreviewConnectionPoints() {
                NodeGraphOptimizedRenderer.renderPreviewConnection(
                    from: points.0,
                    to: points.1
                )
            }
        }
    }
    
    private var selectionRectangleLayer: some View {
        Group {
            if let rect = selectionManager.selectionRect, selectionManager.isSelecting {
                NodeGraphOptimizedRenderer.renderSelectionRectangle(rect: rect)
            }
        }
    }
    
    private var selectionGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                if connectionManager.connectionDragFromNodeID == nil {
                    selectionManager.handleSelectionDrag(value: value, cache: cache)
                }
            }
            .onEnded { _ in
                selectionManager.endSelection()
            }
    }
    
    // MARK: - Setup and Cleanup
    
    private func setupPanel(geometry: GeometryProxy) {
        panelSize = geometry.size
        cache.updateNodeCache(nodes: nodeGraph.nodes)
        setupNotifications(geometry: geometry)
    }
    
    private func cleanupPanel() {
        removeNotifications()
        cancellables.removeAll()
        cache.clearAllCaches()
    }
    
    // MARK: - Helper Methods for UI Creation
    
    private func createNodeView(for node: BaseNode, geometry: GeometryProxy) -> some View {
        NodeView(
            node: node,
            isSelected: selectionManager.isNodeSelected(node.id),
            onSelect: {
                selectionManager.selectNode(node)
                connectionManager.resetConnectionDrag()
            },
            onDelete: { 
                selectionManager.deleteNode(node, nodeGraph: nodeGraph, cache: cache)
            },
            onStartConnection: { fromNodeID, fromPortID, panelPos in
                connectionManager.startPortConnection(
                    fromNodeID: fromNodeID,
                    fromPortID: fromPortID,
                    portPosition: panelPos,
                    cache: cache
                )
            },
            onEndConnection: { toNodeID, toPortID in
                connectionManager.endPortConnection(
                    toNodeID: toNodeID,
                    toPortID: toPortID,
                    cache: cache,
                    nodeGraph: nodeGraph
                )
            },
            onConnectionDrag: { _, _, pos in
                connectionManager.updateConnectionDrag(to: pos, cache: cache)
            },
            onMove: { newPosition in
                nodeGraph.moveNode(node, to: newPosition)
                // Очищаем кэш позиций после перемещения ноды
                cache.clearPositionCacheForNode(node.id)
                cache.clearConnectionCacheForNode(node.id, connections: nodeGraph.connections)
            }
        )
    }
    
    // MARK: - Node Management
    
    private func setupNotifications(geometry: GeometryProxy) {
        panelSize = geometry.size
        NotificationCenter.default.addObserver(
            forName: .createNodeFromMenu,
            object: nil,
            queue: .main
        ) { [weak nodeGraph] notification in
            guard let nodeGraph = nodeGraph else { return }
            handleCreateNodeNotification(notification: notification, geometry: geometry, nodeGraph: nodeGraph)
        }
    }
    
    private func handleCreateNodeNotification(notification: Notification, geometry: GeometryProxy, nodeGraph: NodeGraph) {
        if let type = notification.object as? NodeType {
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            createNode(ofType: type, at: center)
        }
    }
    
    private func removeNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func createNode(ofType type: NodeType, at position: CGPoint) {
        let newNode: BaseNode
        
        switch type {
        case .view:
            newNode = ViewNode(position: position, viewerPanel: viewerController)
        case .input:
            newNode = InputNode(position: position)
        case .corrector:
            newNode = CorrectorNode(position: position)
        }
        
        nodeGraph.addNode(newNode)
        selectionManager.selectNode(newNode)
    }
}
