//
//  NodeGraphPanel.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 14.07.2025.
//

import SwiftUI

struct NodeGraphPanel: View {
    @StateObject private var nodeGraph = NodeGraph()
    @ObservedObject var viewerController: ViewerPanelController
    @State private var selectedNode: BaseNode?
    
    var body: some View {
        ZStack {
            // Фон панели
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .contentShape(Rectangle())
                .contextMenu {
                    createNodeContextMenu()
                }
            
            ForEach(nodeGraph.nodes, id: \.id) { node in
                NodeView(node: node, isSelected: selectedNode?.id == node.id)
                    .position(node.position)
                    .onTapGesture {
                        selectedNode = node
                    }
            }
        }
        .clipped()
        .border(Color.gray.opacity(0.3), width: 1)
    }
    
    @ViewBuilder
    private func createNodeContextMenu() -> some View {
        Button(action: {
            createViewNode()
        }) {
            Label("Create Viewer Node", systemImage: "eye")
        }
    }
    
    private func createViewNode() {
        let newPosition = CGPoint(x: 200, y: 200)
        let viewerNode = ViewNode(position: newPosition, viewerPanel: viewerController)
        nodeGraph.addNode(viewerNode)
    }
}
