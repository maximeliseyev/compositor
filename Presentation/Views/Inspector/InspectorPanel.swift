//
//  InspectorPanel.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 15.07.2025.
//

import SwiftUI

struct InspectorPanel: View {
    let selectedNode: BaseNode?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Inspector")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.1))
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let node = selectedNode {
                        // Universal node inspector
                        UniversalNodeInspector(node: node)
                    } else {
                        // Empty state
                        EmptyInspectorView()
                    }
                }
                .padding(16)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .border(Color.gray.opacity(0.3), width: 1)
    }
}

// MARK: - Empty Inspector View

struct EmptyInspectorView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 32))
                .foregroundColor(.gray)
            
            Text("No node selected")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Select a node in the graph to see its properties and controls")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Universal Node Inspector

struct UniversalNodeInspector: View {
    let node: BaseNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Node Header
            NodeHeaderView(node: node)
            
            Divider()
            
            // Node-specific inspector using factory
            NodeInspectorFactory.createInspector(for: node)
        }
    }
}
