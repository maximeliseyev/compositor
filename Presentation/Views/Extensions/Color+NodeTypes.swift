//
//  Color+NodeTypes.swift
//  Compositor
//
//  SwiftUI Color Extensions for Node Types
//
//  Created by Architecture Refactor on 12.08.2025.
//

import SwiftUI
import Foundation

// MARK: - Color Extension for Node Types

extension Color {
    
    /// Получает цвет для типа ноды из метаданных
    static func forNodeType(_ nodeType: NodeType) -> Color {
        switch nodeType.colorName {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "indigo": return .indigo
        case "pink": return .pink
        case "red": return .red
        case "yellow": return .yellow
        case "cyan": return .cyan
        case "mint": return .mint
        case "teal": return .teal
        default: return .gray
        }
    }
    
    /// Статические цвета для нод (для быстрого доступа)
    struct NodeColors {
        static let input = Color.blue
        static let output = Color.green
        static let processing = Color.orange
        static let effect = Color.purple
        static let utility = Color.gray
        static let professional = Color.pink
    }
}

// MARK: - NodeType Extension для SwiftUI

extension NodeType {
    
    /// Возвращает SwiftUI Color для ноды
    var color: Color {
        return Color.forNodeType(self)
    }
    
    /// Возвращает цвет с прозрачностью для фона
    var backgroundColorWithOpacity: Color {
        return color.opacity(0.1)
    }
    
    /// Возвращает цвет для границы
    var borderColor: Color {
        return color.opacity(0.3)
    }
}
