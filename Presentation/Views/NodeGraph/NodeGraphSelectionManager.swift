//
//  NodeGraphSelectionManager.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 17.07.2025.
//

import SwiftUI
import Foundation

/// Управляет выделением нод и операциями с выделенными элементами
@MainActor
class NodeGraphSelectionManager: ObservableObject {
    // MARK: - Properties
    
    @Published var selectedNode: BaseNode? = nil
    @Published var selectedNodes: Set<UUID> = []
    @Published var selectionRect: CGRect? = nil
    @Published var isSelecting: Bool = false
    
    // MARK: - Selection Management
    
    func selectNode(_ node: BaseNode) {
        selectedNode = node
        selectedNodes = [node.id]
    }
    
    func selectNodes(_ nodes: [BaseNode]) {
        selectedNodes = Set(nodes.map { $0.id })
        selectedNode = nodes.first
    }
    
    func addToSelection(_ node: BaseNode) {
        selectedNodes.insert(node.id)
        if selectedNode == nil {
            selectedNode = node
        }
    }
    
    func removeFromSelection(_ node: BaseNode) {
        selectedNodes.remove(node.id)
        if selectedNode?.id == node.id {
            selectedNode = selectedNodes.isEmpty ? nil : nil // Можно улучшить логику выбора следующей ноды
        }
    }
    
    func deselectAll() {
        selectedNodes.removeAll()
        selectedNode = nil
        resetSelectionRect()
    }
    
    func isNodeSelected(_ nodeId: UUID) -> Bool {
        return selectedNodes.contains(nodeId)
    }
    
    // MARK: - Selection Rectangle Management
    
    func handleSelectionDrag(value: DragGesture.Value, cache: NodeGraphCache) {
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
        
        // Используем кэшированные ноды для выбора
        let selectedNodeIds = cache.getAllCachedNodes()
            .filter { node in rect.contains(node.position) }
            .map { $0.id }
        
        selectedNodes = Set(selectedNodeIds)
    }
    
    func endSelection() {
        isSelecting = false
        selectionRect = nil
    }
    
    private func resetSelectionRect() {
        selectionRect = nil
        isSelecting = false
    }
    
    // MARK: - Node Operations
    
    func deleteSelectedNodes(nodeGraph: NodeGraph, cache: NodeGraphCache) {
        let nodesToDelete = cache.getAllCachedNodes().filter { selectedNodes.contains($0.id) }
        
        for node in nodesToDelete {
            nodeGraph.removeNode(node)
            cache.removeNodeFromCache(node.id)
            cache.clearConnectionCacheForNode(node.id, connections: nodeGraph.connections)
        }
        
        deselectAll()
    }
    
    func deleteNode(_ node: BaseNode, nodeGraph: NodeGraph, cache: NodeGraphCache) {
        nodeGraph.removeNode(node)
        cache.removeNodeFromCache(node.id)
        cache.clearConnectionCacheForNode(node.id, connections: nodeGraph.connections)
        
        if selectedNode?.id == node.id {
            selectedNode = nil
        }
        selectedNodes.remove(node.id)
    }
    
    // MARK: - Utility Methods
    
    func getSelectedNodes(cache: NodeGraphCache) -> [BaseNode] {
        return cache.getAllCachedNodes().filter { selectedNodes.contains($0.id) }
    }
    
    func hasSelection() -> Bool {
        return !selectedNodes.isEmpty
    }
    
    func selectionCount() -> Int {
        return selectedNodes.count
    }
} 