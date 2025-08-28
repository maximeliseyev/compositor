//
//  NodeInspectors.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 19.07.2025.
//

import SwiftUI

// MARK: - Node Inspector Factory

@MainActor
struct NodeInspectorFactory {
    static func createInspector(for node: BaseNode) -> some View {
        return NodeRegistry.shared.createInspector(for: node)
    }
}

// MARK: - Universal Parameter Inspector

struct UniversalParameterInspector: View {
    let node: BaseNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parameters")
                .font(.headline)
            
            let parameterKeys = node.getParameterKeys()
            if parameterKeys.isEmpty {
                Text("No parameters available")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                ForEach(parameterKeys, id: \.self) { key in
                    ParameterControlView(
                        node: node,
                        parameterKey: key,
                        value: node.getParameter(key: key)
                    )
                }
            }
        }
    }
}

// MARK: - Parameter Control View

struct ParameterControlView: View {
    let node: BaseNode
    let parameterKey: String
    let value: Any?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(parameterKey.capitalized)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let floatValue = value as? Double {
                HStack {
                    Slider(
                        value: Binding(
                            get: { floatValue },
                            set: { node.setParameter(key: parameterKey, value: $0) }
                        ),
                        in: 0...1
                    )
                    Text(String(format: "%.2f", floatValue))
                        .font(.caption)
                        .monospacedDigit()
                        .frame(width: 40)
                }
            } else if let intValue = value as? Int {
                HStack {
                    Slider(
                        value: Binding(
                            get: { Double(intValue) },
                            set: { node.setParameter(key: parameterKey, value: Int($0)) }
                        ),
                        in: 0...100
                    )
                    Text("\(intValue)")
                        .font(.caption)
                        .monospacedDigit()
                        .frame(width: 40)
                }
            } else if let boolValue = value as? Bool {
                Toggle(parameterKey.capitalized, isOn: Binding(
                    get: { boolValue },
                    set: { node.setParameter(key: parameterKey, value: $0) }
                ))
            } else {
                Text("Unsupported parameter type")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - View Node Inspector

struct ViewNodeInspector: View {
    @ObservedObject var node: ViewNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Universal parameters
            UniversalParameterInspector(node: node)
            
            Divider()
            
            // View-specific controls
            VStack(alignment: .leading, spacing: 12) {
                Text("View Options")
                    .font(.headline)
                
                Text("View controls will be implemented here")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Blur Node Inspector

struct BlurNodeInspector: View {
    @ObservedObject var node: BlurNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Universal parameters
            UniversalParameterInspector(node: node)
            
            Divider()
            
            // Blur-specific controls
            VStack(alignment: .leading, spacing: 12) {
                Text("Blur Settings")
                    .font(.headline)
                
                // Blur radius control
                VStack(alignment: .leading, spacing: 4) {
                    Text("Radius")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                                    HStack {
                    Slider(
                        value: Binding(
                            get: { node.radius },
                            set: { node.radius = $0 }
                        ),
                        in: 0...50
                    )
                    Text(String(format: "%.1f", node.radius))
                        .font(.caption)
                        .monospacedDigit()
                        .frame(width: 40)
                }
                }
            }
        }
    }
}

// MARK: - Base Node Inspector

struct BaseNodeInspector: View {
    let node: BaseNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Universal parameters
            UniversalParameterInspector(node: node)
            
            Divider()
            
            // Basic node info
            VStack(alignment: .leading, spacing: 12) {
                Text("Node Info")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Position:")
                            .foregroundColor(.secondary)
                        Text("(\(Int(node.position.x)), \(Int(node.position.y)))")
                        Spacer()
                    }
                    .font(.caption)
                    
                    HStack {
                        Text("Connections:")
                            .foregroundColor(.secondary)
                        Text("In: \(node.inputConnections.count), Out: \(node.outputConnections.count)")
                        Spacer()
                    }
                    .font(.caption)
                    
                    HStack {
                        Text("Type:")
                            .foregroundColor(.secondary)
                        Text(node.type.displayName)
                        Spacer()
                    }
                    .font(.caption)
                }
            }
        }
    }
} 
