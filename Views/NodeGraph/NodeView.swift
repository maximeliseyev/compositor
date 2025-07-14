//
//  NodeView.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 14.07.2025.
//


import SwiftUI

struct NodeView: View {
    let node: BaseNode
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.8))
                .frame(width: 120, height: 80)
                .overlay(
                    VStack {
                        Image(systemName: nodeIcon)
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text(node.type.rawValue)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: 2)
                )
        }
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            Button(action: {
                onDelete()
            }) {
                Label("Delete Node", systemImage: "trash")
            }
        }
    }
    
    private var nodeIcon: String {
        switch node.type {
        case .view:
            return "eye"
        default:
            return "square"
        }
    }
}
