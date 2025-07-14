//
//  NodeView.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 14.07.2025.
//


import SwiftUI
// import Core.Nodes.BaseNode // If using modulemaps, otherwise ensure BaseNode.swift is in the target

struct NodeView: View {
    let node: BaseNode
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    // Connection gestures
    let onStartConnection: ((UUID, CGPoint) -> Void)?
    let onEndConnection: ((UUID) -> Void)?
    let onConnectionDrag: ((CGPoint) -> Void)?
    let onMove: ((CGPoint) -> Void)?
    
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if nodeHasInput {
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 14, height: 14)
                        .cornerRadius(2)
                        .offset(y: -2)
                        .zIndex(2)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { _ in
                                    onEndConnection?(node.id)
                                }
                        )
                } else {
                    Spacer().frame(height: 7)
                }
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.8))
                        .frame(width: 90, height: 30)
                        .overlay(
                            VStack(spacing: 4) {
                                Text(node.type.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: 2)
                        )
                        .offset(dragOffset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDragging = true
                                    dragOffset = value.translation
                                }
                                .onEnded { value in
                                    isDragging = false
                                    dragOffset = .zero
                                    let newPosition = CGPoint(x: node.position.x + value.translation.width, y: node.position.y + value.translation.height)
                                    onMove?(newPosition)
                                }
                        )
                }
                if nodeHasOutput {
                    Triangle()
                        .fill(Color.orange)
                        .frame(width: 18, height: 12)
                        .rotationEffect(.degrees(180))
                        .offset(y: 2)
                        .zIndex(2)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    // Output port drag: start or update connection
                                    let portPosition = CGPoint(x: 60, y: 60 + 12) // Node center bottom
                                    onStartConnection?(node.id, portPosition)
                                    onConnectionDrag?(value.location)
                                }
                                .onEnded { _ in }
                        )
                } else {
                    Spacer().frame(height: 7)
                }
            }
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
    
    // Helper: which nodes have input/output
    private var nodeHasInput: Bool {
        switch node.type {
        case .view: return true
        case .corrector: return true
        default: return false
        }
    }
    private var nodeHasOutput: Bool {
        switch node.type {
        case .input: return true
        case .corrector: return true
        default: return false
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

// Triangle shape for output port
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
