//
//  MetalNodeInspector.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 12.08.2025.
//

import SwiftUI

/// Инспектор для Metal нод с дополнительными контролами
struct MetalNodeInspector: View {
    @ObservedObject var node: MetalNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Заголовок ноды
            NodeHeaderView(node: node)
            
            Divider()
            
            // Информация о рендерере
            RendererInfoSection(node: node)
            
            Divider()
            
            // Выбор режима обработки
            ProcessingModeSection(node: node)
            
            Divider()
            
            // Параметры ноды
            NodeParametersSection(node: node)
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 250, maxWidth: 300)
    }
}

// MARK: - Renderer Info Section

struct RendererInfoSection: View {
    @ObservedObject var node: MetalNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Renderer Info")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                Image(systemName: node.isMetalSupported() ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(node.isMetalSupported() ? .green : .red)
                
                Text(node.isMetalSupported() ? "Metal Available" : "Metal Not Available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if node.isMetalSupported() {
                Text(node.getPerformanceInfo())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Processing Mode Section

struct ProcessingModeSection: View {
    @ObservedObject var node: MetalNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Processing Mode")
                .font(.headline)
                .foregroundColor(.primary)
            
            Picker("Mode", selection: $node.processingMode) {
                Text("Auto").tag(MetalNode.ProcessingMode.auto)
                Text("Metal").tag(MetalNode.ProcessingMode.metal)
                Text("Core Image").tag(MetalNode.ProcessingMode.coreImage)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Text(modeDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var modeDescription: String {
        switch node.processingMode {
        case .auto:
            return "Automatically choose the best available renderer"
        case .metal:
            return "Force Metal rendering (may fallback to Core Image)"
        case .coreImage:
            return "Use Core Image framework"
        }
    }
}

// MARK: - Node Parameters Section

struct NodeParametersSection: View {
    @ObservedObject var node: MetalNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parameters")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Динамические параметры в зависимости от типа ноды
            if node is BlurNode {
                BlurParameters(node: node as! BlurNode)
            } else {
                GenericParameters(node: node)
            }
        }
    }
}


// MARK: - Metal Blur Parameters

struct BlurParameters: View {
    @ObservedObject var node: BlurNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Radius
            ParameterSlider(
                title: "Radius",
                value: Binding(
                    get: { node.parameters["radius"] as? Float ?? 5.0 },
                    set: { node.setParameter(key: "radius", value: $0) }
                ),
                range: 0.0...50.0,
                step: 1.0
            )
            
            // Blur Type
            VStack(alignment: .leading, spacing: 4) {
                Text("Blur Type")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Picker("Blur Type", selection: Binding(
                    get: { node.parameters["blurType"] as? String ?? "gaussian" },
                    set: { node.setParameter(key: "blurType", value: $0) }
                )) {
                    Text("Gaussian").tag("gaussian")
                    Text("Box").tag("box")
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
    }
}

// MARK: - Generic Parameters

struct GenericParameters: View {
    @ObservedObject var node: MetalNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(node.getParameterKeys(), id: \.self) { key in
                if let value = node.getParameter(key: key) {
                    ParameterRow(key: key, value: value, node: node)
                }
            }
        }
    }
}

// MARK: - Parameter Row

struct ParameterRow: View {
    let key: String
    let value: Any
    @ObservedObject var node: MetalNode
    
    var body: some View {
        HStack {
            Text(key.capitalized)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            if let floatValue = value as? Float {
                Text(String(format: "%.2f", floatValue))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if let intValue = value as? Int {
                Text("\(intValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if let stringValue = value as? String {
                Text(stringValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("\(value)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Parameter Slider

struct ParameterSlider: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let step: Float
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(String(format: "%.2f", value))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Slider(value: $value, in: range, step: step)
                .accentColor(.blue)
        }
    }
}
