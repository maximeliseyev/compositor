//
//  MetalSettingsPanel.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 12.08.2025.
//

import SwiftUI

/// Панель настроек Metal рендеринга
struct MetalSettingsPanel: View {
    @EnvironmentObject var metalManager: MetalRenderingManager
    @State private var showingSystemInfo = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Заголовок
            HStack {
                Image(systemName: "cpu")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Metal Rendering Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Индикатор статуса
                HStack(spacing: 4) {
                    Circle()
                        .fill(metalManager.isMetalEnabled ? .green : .red)
                        .frame(width: 8, height: 8)
                    
                    Text(metalManager.isMetalEnabled ? "Enabled" : "Disabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Основные настройки
            VStack(alignment: .leading, spacing: 16) {
                Text("Rendering")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Переключатель Metal
                HStack {
                    Toggle("Enable Metal Rendering", isOn: $metalManager.isMetalEnabled)
                        .onChange(of: metalManager.isMetalEnabled) { _, newValue in
                            metalManager.toggleMetalRendering()
                        }
                    
                    Spacer()
                    
                    Button("Reset") {
                        metalManager.isMetalEnabled = true
                        metalManager.preferredRenderer = "metal"
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
                
                // Выбор рендерера
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preferred Renderer")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    // TODO: Восстановить после исправления импортов
                    Text("Renderer selection not available")
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Настройки производительности
            VStack(alignment: .leading, spacing: 16) {
                Text("Performance")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Режим производительности
                VStack(alignment: .leading, spacing: 8) {
                    Text("Performance Mode")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    // TODO: Восстановить после исправления импортов
                    Text("Performance mode selection not available")
                        .foregroundColor(.secondary)
                }
                
                // Статистика производительности
                VStack(alignment: .leading, spacing: 8) {
                    Text("Performance Statistics")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Frame Count")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(metalManager.frameCount)")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Avg Frame Time")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f ms", metalManager.averageFrameTime * 1000))
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("GPU Usage")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f%%", metalManager.gpuUtilization))
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            Divider()
            
            // Управление памятью
            VStack(alignment: .leading, spacing: 16) {
                Text("Memory Management")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack {
                    Button("Cleanup Memory") {
                        metalManager.cleanupMemory()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Show Memory Info") {
                        print(metalManager.getMemoryInfo())
                    }
                    .buttonStyle(.borderless)
                }
            }
            
            Divider()
            
            // Дополнительные опции
            VStack(alignment: .leading, spacing: 16) {
                Text("Debug & Info")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack {
                    Button("System Information") {
                        showingSystemInfo.toggle()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Print Debug Info") {
                        print(metalManager.getSystemInfo())
                    }
                    .buttonStyle(.borderless)
                }
            }
            
            Spacer()
        }
        .padding()
        #if os(macOS)
        .frame(minWidth: 300, maxWidth: 400)
        #elseif os(iOS)
        .frame(maxWidth: .infinity)
        #endif
        .sheet(isPresented: $showingSystemInfo) {
            SystemInfoView()
                .environmentObject(metalManager)
        }
    }
}

// MARK: - System Info View

struct SystemInfoView: View {
    @EnvironmentObject var metalManager: MetalRenderingManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("System Information")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderless)
            }
            
            Divider()
            
            ScrollView {
                Text(metalManager.getSystemInfo())
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
            
            Divider()
            
            HStack {
                Button("Copy to Clipboard") {
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(metalManager.getSystemInfo(), forType: .string)
                    #elseif os(iOS)
                    UIPasteboard.general.string = metalManager.getSystemInfo()
                    #endif
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Print to Console") {
                    print(metalManager.getSystemInfo())
                }
                .buttonStyle(.borderless)
            }
        }
        .padding()
        #if os(macOS)
        .frame(width: 500, height: 400)
        #elseif os(iOS)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
    }
}

