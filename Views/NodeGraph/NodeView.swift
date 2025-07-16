//
//  NodeView.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 14.07.2025.
//

import SwiftUI

struct NodeView: View {
    @ObservedObject var node: BaseNode
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    let onStartConnection: ((UUID, CGPoint) -> Void)?
    let onEndConnection: ((UUID) -> Void)?
    let onConnectionDrag: ((CGPoint) -> Void)?
    let onMove: ((CGPoint) -> Void)?
    
    @GestureState private var dragOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            nodeBodyView
            inputPortsView
            outputPortsView
        }
        .gesture(
            DragGesture(coordinateSpace: .named("NodeGraphPanel"))
                .updating($dragOffset) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    let newPosition = CGPoint(
                        x: node.position.x + value.translation.width,
                        y: node.position.y + value.translation.height
                    )
                    onMove?(newPosition)
                }
        )
        .position(
            x: node.position.x + dragOffset.width,
            y: node.position.y + dragOffset.height
        )
    }
    
    private var nodeBodyView: some View {
        HStack {
            RoundedRectangle(cornerRadius: NodeConstants.nodeCornerRadius)
                .fill(nodeBackgroundColor)
                .frame(width: NodeConstants.nodeWidth, height: NodeConstants.nodeHeight)
                .overlay(
                    VStack(spacing: 4) {
                        Text(node.title)
                            .font(.caption)
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: NodeConstants.nodeCornerRadius)
                        .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: NodeConstants.selectionBorderWidth)
                )
                .onTapGesture {
                    onSelect()
                }
        }
    }
    
    private var nodeBackgroundColor: Color {
        return Color.gray.opacity(0.8)
    }
    
    private var inputPortsView: some View {
        HStack(spacing: 8) {
            ForEach(Array(node.inputPorts.enumerated()), id: \.element.id) { index, port in
                GeometryReader { geometry in
                    NodePortView(
                        port: port,
                        isConnected: node.inputConnections.contains { $0.toNode == node.id },
                        onStartConnection: { panelPos in
                            // Position is in NodeGraphPanel coordinate space
                            onStartConnection?(node.id, panelPos)
                        },
                        onEndConnection: {
                            onEndConnection?(node.id)
                        },
                        onConnectionDrag: { panelPos in
                            // Position is in NodeGraphPanel coordinate space
                            onConnectionDrag?(panelPos)
                        }
                    )
                }
                .frame(width: NodeConstants.portSize, height: NodeConstants.portSize)
                .offset(x: CGFloat(index - node.inputPorts.count/2) * NodeConstants.portOffset, y: -NodeConstants.nodeHeight/2 - NodeConstants.portSize/2)
            }
        }
    }
    
    private var outputPortsView: some View {
        HStack(spacing: 8) {
            ForEach(Array(node.outputPorts.enumerated()), id: \.element.id) { index, port in
                GeometryReader { geometry in
                    NodePortView(
                        port: port,
                        isConnected: node.outputConnections.contains { $0.fromNode == node.id },
                        onStartConnection: { panelPos in
                            // Position is in NodeGraphPanel coordinate space
                            onStartConnection?(node.id, panelPos)
                        },
                        onEndConnection: {
                            onEndConnection?(node.id)
                        },
                        onConnectionDrag: { panelPos in
                            // Position is in NodeGraphPanel coordinate space
                            onConnectionDrag?(panelPos)
                        }
                    )
                }
                .frame(width: NodeConstants.portSize, height: NodeConstants.portSize)
                .offset(x: CGFloat(index - node.outputPorts.count/2) * NodeConstants.portOffset, y: NodeConstants.nodeHeight/2 + NodeConstants.portSize/2)
            }
        }
    }
}

struct NodePortView: View {
    let port: NodePort
    let isConnected: Bool
    
    let onStartConnection: ((CGPoint) -> Void)?
    let onEndConnection: (() -> Void)?
    let onConnectionDrag: ((CGPoint) -> Void)?
    
    var body: some View {
        Circle()
            .fill(portColor)
            .frame(width: 10, height: 10)
            .onTapGesture {
                if port.type == .input {
                    onEndConnection?()
                }
            }
            .gesture(
                DragGesture(coordinateSpace: .named("NodeGraphPanel"))
                    .onChanged { value in
                        if port.type == .output {
                            onConnectionDrag?(value.location)
                        }
                    }
                    .onEnded { value in
                        if port.type == .output {
                            onEndConnection?()
                        }
                    }
            )
    }
    
    private var portBorderColor: Color {
        return portDataTypeColor
    }
    
    private var portDataTypeColor: Color {
        switch port.dataType {
        case .image:
            return .blue
        case .mask:
            return .red
        case .value:
            return .green
        }
    }
    
    private var portColor: Color {
        if isConnected {
            return portDataTypeColor.opacity(0.8)
        } else {
            return portDataTypeColor.opacity(0.4)
        }
    }
}

#Preview {
    NodeView(
        node: CorrectorNode(position: CGPoint(x: 100, y: 100)),
        isSelected: false,
        onSelect: {},
        onDelete: {},
        onStartConnection: nil,
        onEndConnection: nil,
        onConnectionDrag: nil,
        onMove: nil
    )
}
