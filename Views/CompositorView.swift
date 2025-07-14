//
//  CompositorView.swift
//

import SwiftUI


struct CompositorView: View {
    @StateObject private var viewerController = ViewerPanelController()
    @State private var selectedNode: String?
    @State private var leftPanelWidth: CGFloat = 0.75
    @State private var viewerHeight: CGFloat = 0.6
    
    var body: some View {
        GeometryReader { geometry in
                    HStack(spacing: 0) {
                        VStack(spacing: 0) {
                            ViewerPanel(controller: viewerController)
                                .frame(height: geometry.size.height * viewerHeight)
                    
                    ResizableDivider(
                        orientation: .horizontal,
                        onDrag: { delta in
                            let sensitivity: CGFloat = 0.5
                            let adjustedDelta = delta * sensitivity
                            let newHeight = viewerHeight + adjustedDelta / geometry.size.height
                            viewerHeight = max(0.2, min(0.8, newHeight))
                        }
                    )
                    
                    NodeGraphPanel(viewerController: viewerController)
                        .frame(height: geometry.size.height * (1 - viewerHeight))
                }
                .frame(width: geometry.size.width * leftPanelWidth)
                
                ResizableDivider(
                    orientation: .vertical,
                    onDrag: { delta in
                        let sensitivity: CGFloat = 0.5
                        let adjustedDelta = delta * sensitivity
                        let newWidth = leftPanelWidth + adjustedDelta / geometry.size.width
                        leftPanelWidth = max(0.5, min(0.9, newWidth))
                    }
                )
                
                InspectorPanel(selectedNode: selectedNode)
                    .frame(width: geometry.size.width * (1 - leftPanelWidth))
            }
        }
        .navigationTitle("Compositor")
    }
}

struct InspectorPanel: View {
    let selectedNode: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Заголовок
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
            
            // Содержимое
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let nodeName = selectedNode {
                        // Информация о выбранной ноде
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Selected Node")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text(nodeName)
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                        
                        Divider()
                                                
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 32))
                                .foregroundColor(.gray)
                            
                            Text("No node selected")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("Select a node in the graph to see its parameters")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 40)
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


struct GridBackground: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 20
            
            context.stroke(
                Path { path in
                    for x in stride(from: 0, through: size.width, by: spacing) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    for y in stride(from: 0, through: size.height, by: spacing) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                },
                with: .color(.gray.opacity(0.1)),
                lineWidth: 0.5
            )
        }
    }
}

struct ResizableDivider: View {
    enum Orientation {
        case horizontal
        case vertical
    }
    
    let orientation: Orientation
    let onDrag: (CGFloat) -> Void
    
    @State private var isHovering = false
    @State private var isDragging = false
    
    var body: some View {
        Rectangle()
            .fill(isDragging ? Color.blue.opacity(0.3) : Color.clear)
            .overlay(
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(
                        width: orientation == .vertical ? 1 : nil,
                        height: orientation == .horizontal ? 1 : nil
                    )
            )
            .frame(
                width: orientation == .vertical ? 8 : nil,
                height: orientation == .horizontal ? 8 : nil
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    NSCursor.resizeLeftRight.set()
                } else if !isDragging {
                    NSCursor.arrow.set()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            switch orientation {
                            case .horizontal:
                                NSCursor.resizeUpDown.set()
                            case .vertical:
                                NSCursor.resizeLeftRight.set()
                            }
                        }
                        
                        let delta = orientation == .vertical ? value.translation.width : value.translation.height
                        onDrag(delta)
                    }
                    .onEnded { _ in
                        isDragging = false
                        if isHovering {
                            switch orientation {
                            case .horizontal:
                                NSCursor.resizeUpDown.set()
                            case .vertical:
                                NSCursor.resizeLeftRight.set()
                            }
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
            )
    }
}
