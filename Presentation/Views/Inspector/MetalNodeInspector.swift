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
            // Universal parameters
            UniversalParameterInspector(node: node)
            
            Divider()
            
            // Информация о рендерере
            RendererInfoSection(node: node)
            
            Divider()
            
            // Выбор режима обработки
            ProcessingModeSection(node: node)
            
            Divider()
            
            // Metal-specific parameters
            MetalParametersSection(node: node)
        }
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
            return "Use Core Image rendering (CPU-based)"
        }
    }
}

// MARK: - Metal Parameters Section

struct MetalParametersSection: View {
    @ObservedObject var node: MetalNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metal Parameters")
                .font(.headline)
                .foregroundColor(.primary)
            
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
