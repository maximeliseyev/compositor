//
//  IntegratedSettingsPanel.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 12.08.2025.
//

import SwiftUI
import Metal

/// Интегрированная панель настроек производительности и Metal рендеринга
struct IntegratedSettingsPanel: View {
    
    @StateObject private var performanceViewModel = PerformanceSettingsViewModel()
    @EnvironmentObject var metalManager: MetalRenderingManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: SettingsTab = .performance
    @State private var showingExportDialog = false
    @State private var showingImportDialog = false
    @State private var exportedSettings = ""
    @State private var importSettings = ""
    
    enum SettingsTab: String, CaseIterable {
        case performance = "Performance"
        case metal = "Metal"
        case monitoring = "Monitoring"
        case advanced = "Advanced"
        
        var icon: String {
            switch self {
            case .performance: return "speedometer"
            case .metal: return "cpu"
            case .monitoring: return "chart.line.uptrend.xyaxis"
            case .advanced: return "gearshape.2"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            HStack(spacing: 0) {
                sidebarView
                Divider()
                contentView
            }
            .navigationTitle("")
            #if os(iOS)
            .navigationBarHidden(true)
            #endif
            .toolbar {
                toolbarContent
            }
        }
        #if os(macOS)
        .frame(minWidth: 800, minHeight: 600)
        #elseif os(iOS)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
        .sheet(isPresented: $showingExportDialog) {
            exportDialog
        }
        .sheet(isPresented: $showingImportDialog) {
            importDialog
        }
    }
    
    // MARK: - Computed Properties
    
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
                .padding(.top)
            
            Divider()
            
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack {
                        Image(systemName: tab.icon)
                            .frame(width: 20)
                        Text(tab.rawValue)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(selectedTab == tab ? Color.blue.opacity(0.2) : Color.clear)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .foregroundColor(selectedTab == tab ? .blue : .primary)
            }
            
            Spacer()
            
            // Статус системы
            VStack(alignment: .leading, spacing: 4) {
                Text("System Status")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Circle()
                        .fill(metalManager.isMetalEnabled ? .green : .red)
                        .frame(width: 6, height: 6)
                    Text("Metal: \(metalManager.isMetalEnabled ? "On" : "Off")")
                        .font(.caption)
                }
                
                HStack {
                    Circle()
                        .fill(performanceViewModel.settings.enableAsyncProcessing ? .green : .orange)
                        .frame(width: 6, height: 6)
                    Text("Async: \(performanceViewModel.settings.enableAsyncProcessing ? "On" : "Off")")
                        .font(.caption)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 200)
        .background(Color.gray.opacity(0.05))
    }
    
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                switch selectedTab {
                case .performance:
                    performanceTabContent
                case .metal:
                    metalTabContent
                case .monitoring:
                    monitoringTabContent
                case .advanced:
                    advancedTabContent
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") {
                performanceViewModel.cancelChanges()
                dismiss()
            }
            .disabled(performanceViewModel.isApplyingSettings)
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack {
                if performanceViewModel.settingsChanged {
                    Text("•")
                        .foregroundColor(.orange)
                        .font(.title)
                }
                
                Button("Apply") {
                    Task {
                        await performanceViewModel.applySettings()
                        dismiss()
                    }
                }
                .disabled(!performanceViewModel.settingsChanged || performanceViewModel.isApplyingSettings)
            }
        }
        #elseif os(macOS)
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                performanceViewModel.cancelChanges()
                dismiss()
            }
            .disabled(performanceViewModel.isApplyingSettings)
        }
        
        ToolbarItem(placement: .confirmationAction) {
            HStack {
                if performanceViewModel.settingsChanged {
                    Text("•")
                        .foregroundColor(.orange)
                        .font(.title)
                }
                
                Button("Apply") {
                    Task {
                        await performanceViewModel.applySettings()
                        dismiss()
                    }
                }
                .disabled(!performanceViewModel.settingsChanged || performanceViewModel.isApplyingSettings)
            }
        }
        #endif
    }
    
    // MARK: - Performance Tab
    
    private var performanceTabContent: some View {
        VStack(spacing: 20) {
            // Optimization Mode
            SettingsCard(title: "Optimization Mode", icon: "speedometer") {
                VStack(spacing: 12) {
                    Picker("Mode", selection: $performanceViewModel.settings.optimizationMode) {
                        ForEach(PerformanceSettings.OptimizationMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text(performanceViewModel.settings.optimizationMode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Cache Settings
            SettingsCard(title: "Cache Configuration", icon: "externaldrive") {
                VStack(spacing: 16) {
                    HStack {
                        Text("Max Cache Size")
                        Spacer()
                        Text("\(performanceViewModel.settings.maxCacheSize)")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: Binding(
                            get: { Double(performanceViewModel.settings.maxCacheSize) },
                            set: { performanceViewModel.settings.maxCacheSize = Int($0) }
                        ),
                        in: 10...200,
                        step: 10
                    )
                    
                    HStack {
                        Text("Estimated Memory:")
                        Spacer()
                        Text("\(Int(Double(performanceViewModel.settings.maxCacheSize) * 2.5)) MB")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Processing Options
            SettingsCard(title: "Processing Options", icon: "cpu") {
                VStack(spacing: 12) {
                    Toggle("Enable Async Processing", isOn: $performanceViewModel.settings.enableAsyncProcessing)
                    Toggle("Enable Adaptive Performance", isOn: $performanceViewModel.settings.enableAdaptivePerformance)
                    Toggle("Enable Texture Pooling", isOn: $performanceViewModel.settings.enableTexturePooling)
                }
            }
        }
    }
    
    // MARK: - Metal Tab
    
    private var metalTabContent: some View {
        VStack(spacing: 20) {
            // Metal Status
            SettingsCard(title: "Metal Rendering", icon: "cpu") {
                VStack(spacing: 12) {
                    HStack {
                        Text("Status")
                        Spacer()
                        HStack {
                            Circle()
                                .fill(metalManager.isMetalEnabled ? .green : .red)
                                .frame(width: 8, height: 8)
                            Text(metalManager.isMetalEnabled ? "Enabled" : "Disabled")
                        }
                    }
                    
                    Toggle("Enable Metal Rendering", isOn: .constant(metalManager.isMetalEnabled))
                        .disabled(true) // Только для отображения
                    
                    if metalManager.isMetalEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("GPU Information")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            InfoRow(label: "Device", value: performanceViewModel.systemInfo.gpuName)
                            InfoRow(label: "Max Threads", value: "\(performanceViewModel.systemInfo.maxThreadsPerGroup)")
                            InfoRow(label: "Memory", value: "\(performanceViewModel.systemInfo.availableMemoryMB) MB")
                        }
                        .padding(.top, 8)
                    }
                }
            }
            
            // Shader Settings
            SettingsCard(title: "Shader Configuration", icon: "wand.and.rays") {
                VStack(spacing: 12) {
                    HStack {
                        Text("Thread Group Size")
                        Spacer()
                        Text("\(PerformanceConstants.threadGroupSize.width)×\(PerformanceConstants.threadGroupSize.height)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Pixel Format")
                        Spacer()
                        Text(pixelFormatName(PerformanceConstants.preferredPixelFormat))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Max Concurrent Operations")
                        Spacer()
                        Text("\(PerformanceConstants.maxConcurrentMetalOperations)")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Monitoring Tab
    
    private var monitoringTabContent: some View {
        VStack(spacing: 20) {
            // System Monitoring
            SettingsCard(title: "System Monitoring", icon: "chart.line.uptrend.xyaxis") {
                VStack(spacing: 12) {
                    Toggle("Enable System Monitoring", isOn: $performanceViewModel.settings.enableSystemMonitoring)
                    
                    if performanceViewModel.settings.enableSystemMonitoring {
                        Divider()
                        
                        // Real-time stats
                        VStack(spacing: 12) {
                            HStack {
                                Text("Memory Usage")
                                Spacer()
                                Text("\(String(format: "%.1f", performanceViewModel.currentStats.memoryUsageMB)) MB")
                                    .foregroundColor(.blue)
                            }
                            
                            ProgressView(value: performanceViewModel.currentStats.memoryUsageMB / Double(performanceViewModel.systemInfo.availableMemoryMB))
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            
                            HStack {
                                Text("GPU Utilization")
                                Spacer()
                                Text("\(Int(performanceViewModel.currentStats.gpuUtilization * 100))%")
                                    .foregroundColor(.green)
                            }
                            
                            ProgressView(value: performanceViewModel.currentStats.gpuUtilization)
                                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                            
                            HStack {
                                Text("Thermal State")
                                Spacer()
                                HStack {
                                    Image(systemName: performanceViewModel.currentStats.thermalState.icon)
                                        .foregroundColor(performanceViewModel.currentStats.thermalState.color)
                                    Text(performanceViewModel.currentStats.thermalState.rawValue)
                                        .foregroundColor(performanceViewModel.currentStats.thermalState.color)
                                }
                            }
                        }
                    }
                }
            }
            
            // Performance History
            SettingsCard(title: "Performance History", icon: "chart.bar.fill") {
                VStack(spacing: 12) {
                    Text("Frame Rate History")
                        .font(.subheadline)
                    
                    // Здесь можно добавить график производительности
                    Rectangle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(height: 100)
                        .overlay(
                            Text("Frame Rate Chart\n(Coming Soon)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        )
                        .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Advanced Tab
    
    private var advancedTabContent: some View {
        VStack(spacing: 20) {
            // Constants Configuration
            SettingsCard(title: "Performance Constants", icon: "slider.horizontal.3") {
                VStack(spacing: 12) {
                    Text("These constants control the internal behavior of the performance system.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    Group {
                        InfoRow(label: "Max Texture Pool Size", value: "\(PerformanceConstants.maxTexturePoolSize)")
                        InfoRow(label: "Texture Cleanup Interval", value: "\(Int(PerformanceConstants.textureCleanupInterval))s")
                        InfoRow(label: "Max Texture Memory", value: "\(PerformanceConstants.maxTextureMemoryMB) MB")
                        InfoRow(label: "Cache Expiration", value: "\(Int(PerformanceConstants.cacheExpirationTime))s")
                        InfoRow(label: "Max Concurrent Operations", value: "\(PerformanceConstants.maxConcurrentOperations)")
                    }
                }
            }
            
            // Export/Import
            SettingsCard(title: "Settings Management", icon: "arrow.up.arrow.down.circle") {
                VStack(spacing: 12) {
                    HStack {
                        Button("Export Settings") {
                            exportedSettings = performanceViewModel.exportSettings()
                            showingExportDialog = true
                        }
                        
                        Button("Import Settings") {
                            showingImportDialog = true
                        }
                    }
                    
                    Button("Reset to Defaults") {
                        performanceViewModel.showResetConfirmation = true
                    }
                    .foregroundColor(.red)
                }
            }
            
            // Developer Options
            SettingsCard(title: "Developer Options", icon: "hammer") {
                VStack(spacing: 12) {
                    Text("Debug and development features")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    #if DEBUG
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Verbose Logging", isOn: .constant(PerformanceConstants.enableVerboseLogging))
                            .disabled(true)
                        
                        HStack {
                            Text("Max Log Entries")
                            Spacer()
                            Text("\(PerformanceConstants.maxPerformanceLogEntries)")
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                    }
                    #else
                    Text("Available only in Debug builds")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                    #endif
                }
            }
        }
    }
    
    // MARK: - Export Dialog
    
    private var exportDialog: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Export Performance Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Copy the settings below to share or backup your configuration:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                ScrollView {
                    Text(exportedSettings)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(8)
                        .textSelection(.enabled)
                }
                
                HStack {
                    Button("Copy to Clipboard") {
                        #if os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(exportedSettings, forType: .string)
                        #elseif os(iOS)
                        UIPasteboard.general.string = exportedSettings
                        #endif
                    }
                    
                    Button("Close") {
                        showingExportDialog = false
                    }
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
    
    // MARK: - Import Dialog
    
    private var importDialog: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Import Performance Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Paste your settings JSON below:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextEditor(text: $importSettings)
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                    .frame(height: 200)
                
                HStack {
                    Button("Import") {
                        if performanceViewModel.importSettings(from: importSettings) {
                            showingImportDialog = false
                            importSettings = ""
                        }
                    }
                    .disabled(importSettings.isEmpty)
                    
                    Button("Cancel") {
                        showingImportDialog = false
                        importSettings = ""
                    }
                }
            }
            .padding()
            #if os(macOS)
            .frame(width: 500, height: 350)
            #elseif os(iOS)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            #endif
        }
    }
    
    // MARK: - Helper Methods
    
    private func pixelFormatName(_ format: MTLPixelFormat) -> String {
        switch format {
        case .rgba8Unorm: return "RGBA8"
        case .rgba16Float: return "RGBA16F"
        case .rgba32Float: return "RGBA32F"
        default: return "Unknown"
        }
    }
}

// MARK: - InfoRow Component

/// Строка информации
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
        }
        .font(.caption)
    }
}

// MARK: - Settings Card

/// Карточка настроек с заголовком и содержимым
struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 20)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            
            content
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}
