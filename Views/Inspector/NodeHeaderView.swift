//
//  NodeHeaderView.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 19.07.2025.
//

import SwiftUI
import CoreImage

struct NodeHeaderView: View {
    let node: BaseNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Node type icon
                Image(systemName: nodeTypeIcon)
                    .font(.title2)
                    .foregroundColor(nodeTypeColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(node.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text(node.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Node ID (for debugging)
                if ProcessInfo.processInfo.environment["DEBUG"] == "1" {
                    Text(String(node.id.uuidString.prefix(8)))
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
            }
        }
    }
    
    private var nodeTypeIcon: String {
        return node.type.iconName
    }
    
    private var nodeTypeColor: Color {
        switch node.type {
        case .input:
            return .blue
        case .corrector:
            return .orange
        case .metalCorrector:
            return .purple
        case .metalBlur:
            return .indigo
        case .view:
            return .green
        }
    }
} 