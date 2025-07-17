//
//  NodeGraphRenderer.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 17.07.2025.
//

import SwiftUI

protocol NodeGraphRenderer {
    func renderConnections(connections: [NodeConnection], nodes: [BaseNode], getConnectionPoints: @escaping (NodeConnection, BaseNode, BaseNode) -> (CGPoint, CGPoint)) -> AnyView
}

// TODO: заменить на MetalNodeGraphRenderer
struct CanvasNodeGraphRenderer: NodeGraphRenderer {
    func renderConnections(connections: [NodeConnection], nodes: [BaseNode], getConnectionPoints: @escaping (NodeConnection, BaseNode, BaseNode) -> (CGPoint, CGPoint)) -> AnyView {
        AnyView(
            Canvas { context, size in
                for connection in connections {
                    guard let fromNode = nodes.first(where: { $0.id == connection.fromNode }),
                          let toNode = nodes.first(where: { $0.id == connection.toNode }) else { continue }
                    let (fromPoint, toPoint) = getConnectionPoints(connection, fromNode, toNode)
                    var path = Path()
                    path.move(to: fromPoint)
                    path.addLine(to: toPoint)
                    context.stroke(path, with: .color(.white), lineWidth: 1)
                }
            }
            .allowsHitTesting(false)
        )
    }
}
