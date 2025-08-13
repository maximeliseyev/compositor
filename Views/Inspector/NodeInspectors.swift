//
//  NodeInspectors.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 19.07.2025.
//

import SwiftUI

// MARK: - Node Inspector Factory

struct NodeInspectorFactory {
    static func createInspector(for node: BaseNode) -> some View {
        switch node {
        case let metalNode as MetalNode:
            return AnyView(MetalNodeInspector(node: metalNode))
        case let correctorNode as CorrectorNode:
            return AnyView(CorrectorNodeInspector(node: correctorNode))
        case let viewNode as ViewNode:
            return AnyView(ViewNodeInspector(node: viewNode))
        default:
            return AnyView(BaseNodeInspector(node: node))
        }
    }
}

// MARK: - Corrector Node Inspector

struct CorrectorNodeInspector: View {
    @ObservedObject var node: CorrectorNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Image Corrections")
                .font(.headline)
            
            Text("Correction controls will be implemented here")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - View Node Inspector

struct ViewNodeInspector: View {
    @ObservedObject var node: ViewNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("View Options")
                .font(.headline)
            
            Text("View controls will be implemented here")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Base Node Inspector

struct BaseNodeInspector: View {
    let node: BaseNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Node Properties")
                .font(.headline)
            
            // Basic node info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Position:")
                        .foregroundColor(.secondary)
                    Text("(\(Int(node.position.x)), \(Int(node.position.y)))")
                    Spacer()
                }
                .font(.caption)
                
                HStack {
                    Text("Connections:")
                        .foregroundColor(.secondary)
                    Text("In: \(node.inputConnections.count), Out: \(node.outputConnections.count)")
                    Spacer()
                }
                .font(.caption)
            }
        }
    }
} 