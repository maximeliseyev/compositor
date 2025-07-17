//
//  CompositorView.swift
//

import SwiftUI

// MARK: - Panel Visibility Manager
class PanelVisibilityManager: ObservableObject {
    @Published var showViewer: Bool = true
    @Published var showNodeGraph: Bool = true
    @Published var showInspector: Bool = true
    
    func toggleViewer() {
        showViewer.toggle()
    }
    
    func toggleNodeGraph() {
        showNodeGraph.toggle()
    }
    
    func toggleInspector() {
        showInspector.toggle()
    }
}

struct CompositorView: View {
    @StateObject private var viewerController = ViewerPanelController()
    @StateObject private var panelVisibility = PanelVisibilityManager()
    @State private var selectedNode: String?
    @State private var leftPanelWidth: CGFloat = 0.75
    @State private var viewerHeight: CGFloat = 0.6
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left panel (Viewer + NodeGraph)
                if panelVisibility.showViewer || panelVisibility.showNodeGraph {
                    VStack(spacing: 0) {
                        // Viewer Panel
                        if panelVisibility.showViewer {
                            ViewerPanel(controller: viewerController)
                                .frame(height: calculateViewerHeight(geometry: geometry))
                        }
                        
                        // Divider between Viewer and NodeGraph
                        if panelVisibility.showViewer && panelVisibility.showNodeGraph {
                            ResizableDivider(
                                orientation: .horizontal,
                                onDrag: { delta in
                                    let sensitivity: CGFloat = 0.5
                                    let adjustedDelta = delta * sensitivity
                                    let newHeight = viewerHeight + adjustedDelta / geometry.size.height
                                    viewerHeight = max(0.1, min(0.9, newHeight))
                                }
                            )
                        }
                        
                        // NodeGraph Panel
                        if panelVisibility.showNodeGraph {
                            NodeGraphPanel(viewerController: viewerController)
                                .frame(height: calculateNodeGraphHeight(geometry: geometry))
                        }
                    }
                    .frame(width: calculateLeftPanelWidth(geometry: geometry))
                }
                
                // Divider between left panels and Inspector
                if (panelVisibility.showViewer || panelVisibility.showNodeGraph) && panelVisibility.showInspector {
                    ResizableDivider(
                        orientation: .vertical,
                        onDrag: { delta in
                            let sensitivity: CGFloat = 0.5
                            let adjustedDelta = delta * sensitivity
                            let newWidth = leftPanelWidth + adjustedDelta / geometry.size.width
                            leftPanelWidth = max(0.3, min(0.95, newWidth))
                        }
                    )
                }
                
                // Inspector Panel
                if panelVisibility.showInspector {
                    InspectorPanel(selectedNode: selectedNode)
                        .frame(width: calculateInspectorWidth(geometry: geometry))
                }
            }
        }
        .navigationTitle("Compositor")
        .onAppear {
            setupNotifications()
        }
        .onDisappear {
            removeNotifications()
        }
    }
    
    // MARK: - Panel Size Calculations
    
    private func calculateViewerHeight(geometry: GeometryProxy) -> CGFloat {
        if panelVisibility.showViewer && panelVisibility.showNodeGraph {
            return geometry.size.height * viewerHeight
        } else if panelVisibility.showViewer {
            return geometry.size.height
        }
        return 0
    }
    
    private func calculateNodeGraphHeight(geometry: GeometryProxy) -> CGFloat {
        if panelVisibility.showViewer && panelVisibility.showNodeGraph {
            return geometry.size.height * (1 - viewerHeight)
        } else if panelVisibility.showNodeGraph {
            return geometry.size.height
        }
        return 0
    }
    
    private func calculateLeftPanelWidth(geometry: GeometryProxy) -> CGFloat {
        let hasLeftPanels = panelVisibility.showViewer || panelVisibility.showNodeGraph
        let hasInspector = panelVisibility.showInspector
        
        if hasLeftPanels && hasInspector {
            return geometry.size.width * leftPanelWidth
        } else if hasLeftPanels {
            return geometry.size.width
        }
        return 0
    }
    
    private func calculateInspectorWidth(geometry: GeometryProxy) -> CGFloat {
        let hasLeftPanels = panelVisibility.showViewer || panelVisibility.showNodeGraph
        let hasInspector = panelVisibility.showInspector
        
        if hasLeftPanels && hasInspector {
            return geometry.size.width * (1 - leftPanelWidth)
        } else if hasInspector {
            return geometry.size.width
        }
        return 0
    }
    
    // MARK: - Notifications
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .toggleViewerPanel,
            object: nil,
            queue: .main
        ) { _ in
            panelVisibility.toggleViewer()
        }
        
        NotificationCenter.default.addObserver(
            forName: .toggleNodeGraphPanel,
            object: nil,
            queue: .main
        ) { _ in
            panelVisibility.toggleNodeGraph()
        }
        
        NotificationCenter.default.addObserver(
            forName: .toggleInspectorPanel,
            object: nil,
            queue: .main
        ) { _ in
            panelVisibility.toggleInspector()
        }
        
        NotificationCenter.default.addObserver(
            forName: .showAllPanels,
            object: nil,
            queue: .main
        ) { _ in
            panelVisibility.showViewer = true
            panelVisibility.showNodeGraph = true
            panelVisibility.showInspector = true
        }
    }
    
    private func removeNotifications() {
        NotificationCenter.default.removeObserver(self, name: .toggleViewerPanel, object: nil)
        NotificationCenter.default.removeObserver(self, name: .toggleNodeGraphPanel, object: nil)
        NotificationCenter.default.removeObserver(self, name: .toggleInspectorPanel, object: nil)
        NotificationCenter.default.removeObserver(self, name: .showAllPanels, object: nil)
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
