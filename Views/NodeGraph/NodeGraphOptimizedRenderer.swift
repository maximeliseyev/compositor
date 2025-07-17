//
//  NodeGraphOptimizedRenderer.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 17.07.2025.
//

import SwiftUI
import Foundation

/// Оптимизированный рендерер для NodeGraph с улучшенной производительностью
struct NodeGraphOptimizedRenderer {
    
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

/// Отдельный view для отрисовки линии соединения с оптимизацией
struct ConnectionLineView: View {
    let from: CGPoint
    let to: CGPoint
    let connectionId: UUID
    
    var body: some View {
        Path { path in
            path.move(to: from)
            
            // Можно добавить кривые Безье для более красивых соединений
            if shouldUseBezierCurves {
                let controlPoint1 = CGPoint(x: from.x + curveOffset, y: from.y)
                let controlPoint2 = CGPoint(x: to.x - curveOffset, y: to.y)
                path.addCurve(to: to, control1: controlPoint1, control2: controlPoint2)
            } else {
                path.addLine(to: to)
            }
        }
        .stroke(connectionColor, lineWidth: connectionLineWidth)
        .id(connectionId) // Помогает SwiftUI оптимизировать обновления
    }
    
    private var shouldUseBezierCurves: Bool {
        // Используем кривые только для длинных соединений
        let distance = sqrt(pow(to.x - from.x, 2) + pow(to.y - from.y, 2))
        return distance > 100
    }
    
    private var curveOffset: CGFloat {
        let distance = abs(to.x - from.x)
        return min(distance * 0.5, 50) // Максимальный отступ 50 пикселей
    }
    
    private var connectionColor: Color {
        // Можно добавить разные цвета для разных типов соединений
        .white
    }
    
    private var connectionLineWidth: CGFloat {
        // Можно варьировать толщину в зависимости от типа соединения
        1.0
    }
}

// MARK: - Grid Background View

/// Отдельный view для отрисовки сетки с кэшированием
struct GridBackgroundView: View {
    let size: CGSize
    
    var body: some View {
        Canvas { context, canvasSize in
            NodeGraphOptimizedRenderer.renderGrid(context: context, size: canvasSize)
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
} 