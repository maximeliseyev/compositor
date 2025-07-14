//
//  NodeGraphPanel.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 14.07.2025.
//

import SwiftUI
import AppKit

struct NodeGraphPanel: View {
    @StateObject private var nodeGraph = NodeGraph()
    @ObservedObject var viewerController: ViewerPanelController
    @State private var selectedNode: BaseNode?
    
    var body: some View {
        ZStack {
            // Grid background
            Canvas { context, size in
                let gridSpacing: CGFloat = 40
                let lineColor = Color.gray.opacity(0.2)
                // Vertical lines
                var x: CGFloat = 0
                while x <= size.width {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(lineColor), lineWidth: 1)
                    x += gridSpacing
                }
                // Horizontal lines
                var y: CGFloat = 0
                while y <= size.height {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(lineColor), lineWidth: 1)
                    y += gridSpacing
                }
            }
            // Panel background
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .contentShape(Rectangle())
            
            ForEach(nodeGraph.nodes, id: \.id) { node in
                NodeView(node: node, isSelected: selectedNode?.id == node.id)
                    .position(node.position)
                    .onTapGesture {
                        selectedNode = node
                    }
            }
            
            NodePanelMouseView { location in
                createViewNode(at: location)
            }
            .allowsHitTesting(true)
            .background(Color.clear)
        }
        .clipped()
        .border(Color.gray.opacity(0.3), width: 1)
    }
    
    private func createViewNode(at position: CGPoint) {
        let viewerNode = ViewNode(position: position, viewerPanel: viewerController)
        nodeGraph.addNode(viewerNode)
    }
}

struct NodePanelMouseView: NSViewRepresentable {
    var onCreateViewNode: (CGPoint) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let gesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleClick(_:)))
        gesture.buttonMask = 0x2 // Right mouse button
        view.addGestureRecognizer(gesture)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCreateViewNode: onCreateViewNode)
    }

    class Coordinator: NSObject, NSMenuDelegate {
        var onCreateViewNode: (CGPoint) -> Void

        init(onCreateViewNode: @escaping (CGPoint) -> Void) {
            self.onCreateViewNode = onCreateViewNode
        }

        @objc func handleClick(_ sender: NSClickGestureRecognizer) {
            guard let view = sender.view else { return }
            let location = sender.location(in: view)
            let menu = NSMenu()
            menu.addItem(withTitle: "Create Viewer Node", action: #selector(menuItemSelected(_:)), keyEquivalent: "")
            menu.delegate = self
            // Store location for callback
            objc_setAssociatedObject(menu, &Coordinator.menuLocationKey, NSValue(point: location), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            NSMenu.popUpContextMenu(menu, with: NSApp.currentEvent!, for: view)
        }

        @objc func menuItemSelected(_ sender: NSMenuItem) {
            if let menu = sender.menu,
               let value = objc_getAssociatedObject(menu, &Coordinator.menuLocationKey) as? NSValue {
                let location = value.pointValue
                onCreateViewNode(location)
            }
        }

        static var menuLocationKey: UInt8 = 0
    }
}
