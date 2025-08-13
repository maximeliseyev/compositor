import Foundation
import Metal

/// Styling constants for the Metal NodeGraph canvas.
/// Keep all visual magic values here to make the rendering predictable and easy to tweak.
struct NodeGraphRenderStyle {
    // Background color for the whole canvas (dark gray to reduce eye strain)
    static let backgroundClearColor = MTLClearColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)

    // Grid line color (light gray lines over dark background)
    static let gridLineColor = SIMD4<Float>(0.25, 0.25, 0.25, 1.0)

    // Connection line color (white)
    static let connectionLineColor = SIMD4<Float>(1.0, 1.0, 1.0, 1.0)

    // Preview connection color (yellow)
    static let previewConnectionLineColor = SIMD4<Float>(1.0, 1.0, 0.0, 1.0)

    // Selection rectangle fill color (semi-transparent blue)
    static let selectionFillColor = SIMD4<Float>(0.0, 0.5, 1.0, 0.15)

    // Node body colors
    static let nodeBodyColor = SIMD4<Float>(0.35, 0.35, 0.40, 0.90)
    static let nodeBodySelectedColor = SIMD4<Float>(0.40, 0.40, 0.45, 0.95)

    // Node selection outline styling
    static let selectionOutlineColor = SIMD4<Float>(1.0, 0.85, 0.10, 0.95)   // warm yellow
    static let selectionOutlineThickness: CGFloat = 2                          // in points
}


