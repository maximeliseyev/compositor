//
//  InspectorPanel.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 15.07.2025.
//

import SwiftUI

struct InspectorPanel: View {
    let selectedNode: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Inspector")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.1))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let nodeName = selectedNode {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Selected Node")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text(nodeName)
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                        
                        Divider()
                                                
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 32))
                                .foregroundColor(.gray)
                            
                            Text("No node selected")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("Select a node in the graph to see its parameters")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 40)
                    }
                }
                .padding(16)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .border(Color.gray.opacity(0.3), width: 1)
    }
}
