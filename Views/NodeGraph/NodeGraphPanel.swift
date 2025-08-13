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
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                backgroundLayers(geometry: geo)
                // Metal canvas draws grid, connections, preview and selection
                MetalNodeGraphCanvas(
                    size: geo.size,
                    gridSpacing: 40,
                    connections: nodeGraph.connections.compactMap { conn in
                        if let fromNode = cache.getCachedNode(id: conn.fromNode),
                           let toNode = cache.getCachedNode(id: conn.toNode) {
                            let points = cache.getCachedConnectionPoints(for: conn, fromNode: fromNode, toNode: toNode)
                            return (points.0, points.1)
                        }
                        return nil
                    },
                    previewConnection: connectionManager.hasActiveConnection() ? connectionManager.getPreviewConnectionPoints() : nil,
                    selectionRect: selectionManager.isSelecting ? selectionManager.selectionRect : nil
                )
                .allowsHitTesting(false)
                nodeViewsLayer(geometry: geo)
            }
            .background(Color.clear)
            .coordinateSpace(name: "NodeGraphPanel")
            .onAppear {
                setupPanel(geometry: geo)
            }
            .onDisappear {
                cleanupPanel()
            }
            .onChange(of: nodeGraph.nodes.count) { oldValue, newValue in
                cache.updateNodeCache(nodes: nodeGraph.nodes)
            }
//            .onChange(of: nodeGraph.connections.count) { _ in
//                // Обновляем соединения при изменении
//                DispatchQueue.main.async {
//                    self.updateVideoNodes()
//                }
//            }
        }
        .gesture(selectionGesture)
        .clipped()
        .border(Color.gray.opacity(0.3), width: 1)
    }
    
    // MARK: - Computed Properties for UI Layers
    
    private func backgroundLayers(geometry: GeometryProxy) -> some View {
        ZStack {
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
    
    // Old SwiftUI rendering layers removed — handled by MetalNodeGraphCanvas
    
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
                // Немедленная очистка кэша позиций после окончательного перемещения ноды
                cache.clearPositionCacheForNodeImmediate(node.id)
                cache.clearConnectionCacheForNodeImmediate(node.id, connections: nodeGraph.connections)
            },
            onMoveRealtime: { newPosition in
                nodeGraph.updateNodePositionRealtime(node, to: newPosition)
                // Throttled очистка кэша позиций для обновления связей в реальном времени
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
        case .metalCorrector:
            newNode = MetalCorrectorNode(type: type, position: position)
        case .metalBlur:
            newNode = MetalBlurNode(type: type, position: position)
        }
        
        nodeGraph.addNode(newNode)
        selectionManager.selectNode(newNode)
    }
    
    // MARK: - Simple Connection Processing
    
    private func processConnection(_ connection: NodeConnection) {
        guard let fromNode = nodeGraph.nodes.first(where: { $0.id == connection.fromNode }),
              let toNode = nodeGraph.nodes.first(where: { $0.id == connection.toNode }) else {
            return
        }
        
        // Если это Input -> View соединение
        if let inputNode = fromNode as? InputNode,
           let viewNode = toNode as? ViewNode {
            
            // Получаем данные от Input ноды
            let inputData = inputNode.process(inputs: [])
            
            // Передаем данные в View ноду
            let _ = viewNode.process(inputs: [inputData])
        }
    }
}
