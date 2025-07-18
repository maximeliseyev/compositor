//
//  NodeGraphRenderer.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 17.07.2025.
//

import SwiftUI
import Foundation

struct NodeGraphRenderer {
    
    // MARK: - Grid Rendering
    
    static func renderGrid(context: GraphicsContext, size: CGSize) {
        let gridSpacing: CGFloat = 40 // NodeViewConstants.gridSpacing
        let lineColor = Color.gray.opacity(0.2)
        
        // Оптимизация: рисуем только видимые линии
        let visibleXStart = max(0, Int(0 / gridSpacing) * Int(gridSpacing))
        let visibleXEnd = min(Int(size.width), Int(size.width / gridSpacing + 1) * Int(gridSpacing))
        let visibleYStart = max(0, Int(0 / gridSpacing) * Int(gridSpacing))
        let visibleYEnd = min(Int(size.height), Int(size.height / gridSpacing + 1) * Int(gridSpacing))
        
        // Vertical lines
        var x = CGFloat(visibleXStart)
        while x <= CGFloat(visibleXEnd) {
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(path, with: .color(lineColor), lineWidth: 1)
            x += gridSpacing
        }
        
        // Horizontal lines
        var y = CGFloat(visibleYStart)
        while y <= CGFloat(visibleYEnd) {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(lineColor), lineWidth: 1)
            y += gridSpacing
        }
    }
    
    // MARK: - Preview Connection Rendering
    
    static func renderPreviewConnection(from: CGPoint, to: CGPoint) -> some View {
        Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }
        .stroke(Color.white, lineWidth: 2)
        .allowsHitTesting(false)
    }
    
    // MARK: - Selection Rectangle Rendering
    
    static func renderSelectionRectangle(rect: CGRect) -> some View {
        Rectangle()
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1, dash: [5]))
            .background(Rectangle().fill(Color.accentColor.opacity(0.15)))
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .allowsHitTesting(false)
    }
}

// MARK: - Connection Line View

struct ConnectionLineView: View {
    let from: CGPoint
    let to: CGPoint
    let connectionId: UUID
    let connection: NodeConnection
    let onStartConnectionDrag: ((NodeConnection, CGPoint) -> Void)?
    let onConnectionDrag: ((CGPoint) -> Void)?
    let onEndConnectionDrag: (() -> Void)?
    
    @State private var isDragging = false
    
    var body: some View {
        ZStack {
            // Невидимая толстая линия для лучшего захвата мыши
            Path { path in
                path.move(to: from)
                path.addLine(to: to)
            }
            .stroke(Color.clear, lineWidth: 8)
            .allowsHitTesting(true)
            .gesture(
                DragGesture(coordinateSpace: .named("NodeGraphPanel"))
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            onStartConnectionDrag?(connection, value.startLocation)
                        }
                        onConnectionDrag?(value.location)
                    }
                    .onEnded { _ in
                        isDragging = false
                        onEndConnectionDrag?()
                    }
            )
            
            // Видимая линия связи
            Path { path in
                path.move(to: from)
                path.addLine(to: to)
            }
            .stroke(connectionColor, lineWidth: connectionLineWidth)
            .allowsHitTesting(false)
        }
        .id(connectionId) // Помогает SwiftUI оптимизировать обновления
    }
    
    private var connectionColor: Color {
        // Подсвечиваем связь во время перетаскивания
        if isDragging {
            return .yellow
        }
        return .white
    }
    
    private var connectionLineWidth: CGFloat {
        // Делаем линию толще во время перетаскивания для лучшей видимости
        if isDragging {
            return 2.0
        }
        return 1.0
    }
}

// MARK: - Grid Background View

struct GridBackgroundView: View {
    let size: CGSize
    
    var body: some View {
        Canvas { context, canvasSize in
            NodeGraphRenderer.renderGrid(context: context, size: canvasSize)
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
} 
