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
    @ObservedObject var selectionManager: NodeGraphSelectionManager
    @State private var panelSize: CGSize = .zero
    
    // MARK: - Managers
    @StateObject private var cache = NodeGraphCache()
    @StateObject private var connectionManager = NodeGraphConnectionManager()
    
    // Cancellables для предотвращения утечек памяти
    @State private var cancellables = Set<AnyCancellable>()
    
    // Обработчик графа нод и таймер для видео-тиков
    @State private var graphProcessor: NodeGraphProcessor?
    @State private var videoTimer: Timer?
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                backgroundLayers(geometry: geo)
                // Metal canvas draws grid, connections, preview and selection
                MetalNodeGraphCanvas(
                    size: geo.size,
                    gridSpacing: 40,
                    connections: getCanvasConnections(),
                    previewConnection: getPreviewConnection(),
                    selectionRect: getSelectionRect(),
                    nodes: getCanvasNodes()
                )
                .allowsHitTesting(false)
                nodeViewsLayer(geometry: geo)
            }
            .background(Color.clear)
            .coordinateSpace(name: "NodeGraphPanel")
            .onAppear {
                Task {
                    await setupPanel(geometry: geo)
                }
            }
            .onDisappear {
                cleanupPanel()
            }
            .onChange(of: nodeGraph.connections.map { $0.id }) { _, _ in
                if let last = nodeGraph.connections.last {
                    Task {
                        await processConnection(last)
                    }
                }
            }
            .onChange(of: nodeGraph.nodes.count) { oldValue, newValue in
                cache.updateNodeCache(nodes: nodeGraph.nodes)
            }
            .onChange(of: nodeGraph.connections.count) { _, _ in
                // Обновляем соединения при изменении
                DispatchQueue.main.async {
                    self.updateVideoNodes()
                }
            }
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
                    Task {
                        await createNode(ofType: nodeType, at: location)
                    }
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
    
    private func setupPanel(geometry: GeometryProxy) async {
        panelSize = geometry.size
        cache.updateNodeCache(nodes: nodeGraph.nodes)
        setupNotifications(geometry: geometry)
        // Инициализируем процессор графа
        let processor = NodeGraphProcessor(nodeGraph: nodeGraph)
        graphProcessor = processor
        // Убедимся, что все существующие View-ноды знают о viewerController
        for case let viewNode as ViewNode in nodeGraph.nodes {
            viewNode.viewerPanel = viewerController
        }
        // Пробуем найти существующее соединение Input -> View и настроить Viewer
        if let connection = nodeGraph.connections.last,
           let fromNode = nodeGraph.nodes.first(where: { $0.id == connection.fromNode }) as? InputNode,
           let _ = nodeGraph.nodes.first(where: { $0.id == connection.toNode }) as? ViewNode {
            viewerController.updateFromInputNode(fromNode)
        }
        // Подписка на изменения списка соединений, чтобы настраивать Viewer
        nodeGraph.$connections
            .sink { [weak viewerController, weak nodeGraph] _ in
                guard let nodeGraph = nodeGraph, let viewerController = viewerController else { return }
                if let connection = nodeGraph.connections.last,
                   let input = nodeGraph.nodes.first(where: { $0.id == connection.fromNode }) as? InputNode,
                   let _ = nodeGraph.nodes.first(where: { $0.id == connection.toNode }) as? ViewNode {
                    viewerController.updateFromInputNode(input)
                }
            }
            .store(in: &cancellables)
        // Таймер для обновления видео кадров
//        videoTimer?.invalidate()
//        videoTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { _ in
//            processor.processGraphAsync()
//        }
        // Первичная обработка графа
        await processor.processGraph()
    }
    
    private func cleanupPanel() {
        removeNotifications()
        cancellables.removeAll()
        cache.clearAllCaches()
        videoTimer?.invalidate()
        videoTimer = nil
        graphProcessor = nil
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
            Task {
                await createNode(ofType: type, at: center)
            }
        }
    }
    
    private func removeNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func createNode(ofType type: NodeType, at position: CGPoint) async {
        let newNode = NodeFactory.createNode(type: type, position: position)
        
        // Специальная обработка для ViewNode
        if let viewNode = newNode as? ViewNode {
            viewNode.viewerPanel = viewerController
        }
        
        nodeGraph.addNode(newNode)
        selectionManager.selectNode(newNode)
        // После добавления ноды, перезапускаем процессор графа, чтобы он учитывал новые ноды
        await graphProcessor?.processGraph()
    }
    
    // MARK: - Simple Connection Processing
    
    private func processConnection(_ connection: NodeConnection) async {
        guard let fromNode = nodeGraph.nodes.first(where: { $0.id == connection.fromNode }),
              let toNode = nodeGraph.nodes.first(where: { $0.id == connection.toNode }) else {
            return
        }
        
        // Если это Input -> View соединение
        if let inputNode = fromNode as? InputNode,
           let viewNode = toNode as? ViewNode {
            print("🔗 Processing connection Input(\(inputNode.id)) -> View(\(viewNode.id))")
            
            // Настраиваем Viewer на работу с этим InputNode
            viewerController.updateFromInputNode(inputNode)
            
            // Принудительно обрабатываем граф для получения текущего кадра/изображения
            await graphProcessor?.processGraph()
            
            // Передаем результат в View ноду для синхронизации состояния Viewer
            let inputData = inputNode.process(inputs: [])
            _ = viewNode.process(inputs: [inputData])
            print("📤 Sent initial frame to View node")
        }
    }
    
    // MARK: - Canvas Data Preparation Methods
    
    private func getCanvasConnections() -> [(CGPoint, CGPoint)] {
        return nodeGraph.connections.compactMap { conn in
            if let fromNode = cache.getCachedNode(id: conn.fromNode),
               let toNode = cache.getCachedNode(id: conn.toNode) {
                let points = cache.getCachedConnectionPoints(for: conn, fromNode: fromNode, toNode: toNode)
                return (points.0, points.1)
            }
            return nil
        }
    }
    
    private func getPreviewConnection() -> (CGPoint, CGPoint)? {
        return connectionManager.hasActiveConnection() ? connectionManager.getPreviewConnectionPoints() : nil
    }
    
    private func getSelectionRect() -> CGRect? {
        return selectionManager.isSelecting ? selectionManager.selectionRect : nil
    }
    
    private func getCanvasNodes() -> [NodeRenderItem] {
        return nodeGraph.nodes.map { node in
            NodeRenderItem(
                position: node.position,
                size: CGSize(width: NodeViewConstants.nodeWidth, height: NodeViewConstants.nodeHeight),
                cornerRadius: NodeViewConstants.nodeCornerRadius,
                isSelected: selectionManager.isNodeSelected(node.id)
            )
        }
    }
    
    // MARK: - Video Node Updates
    
    private func updateVideoNodes() {
        // Обновляем видео ноды при изменении соединений
        for case let viewNode as ViewNode in nodeGraph.nodes {
            viewNode.viewerPanel = viewerController
        }
    }
}
