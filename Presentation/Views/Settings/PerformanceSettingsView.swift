//
//  PerformanceSettingsView.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 12.08.2025.
//

import SwiftUI
import Metal

/// Экран настроек производительности
struct PerformanceSettingsView: View {
    
    @StateObject private var viewModel = PerformanceSettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    systemInfoSection
                    optimizationModeSection
                    cacheSettingsSection
                    textureSettingsSection
                    processingSettingsSection
                    monitoringSection
                    performanceStatsSection
                    actionsSection
                }
                .padding()
            }
            .navigationTitle("Performance Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.cancelChanges()
                        dismiss()
                    }
                    .disabled(viewModel.isApplyingSettings)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        Task {
                            await viewModel.applySettings()
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.settingsChanged || viewModel.isApplyingSettings)
                }
            }
            #elseif os(macOS)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.cancelChanges()
                        dismiss()
                    }
                    .disabled(viewModel.isApplyingSettings)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        Task {
                            await viewModel.applySettings()
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.settingsChanged || viewModel.isApplyingSettings)
                }
            }
            #endif
        }
        .alert("Reset to Defaults", isPresented: $viewModel.showResetConfirmation) {
            Button("Reset", role: .destructive) {
                viewModel.resetToDefaults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset all performance settings to their default values. Are you sure?")
        }
    }
    
    // MARK: - System Info Section
    
    private var systemInfoSection: some View {
        SettingsSection(title: "System Information", icon: "info.circle") {
            VStack(spacing: 12) {
                InfoRow(label: "Device", value: viewModel.systemInfo.deviceName)
                InfoRow(label: "Metal Support", value: viewModel.systemInfo.metalSupported ? "Available" : "Not Available")
                InfoRow(label: "GPU", value: viewModel.systemInfo.gpuName)
                InfoRow(label: "Available Memory", value: "\(viewModel.systemInfo.availableMemoryMB) MB")
                InfoRow(label: "Max Threads per Group", value: "\(viewModel.systemInfo.maxThreadsPerGroup)")
            }
        }
    }
    
    // MARK: - Optimization Mode Section
    
    private var optimizationModeSection: some View {
        SettingsSection(title: "Optimization Mode", icon: "speedometer") {
            VStack(spacing: 12) {
                Picker("Mode", selection: $viewModel.settings.optimizationMode) {
                    ForEach(PerformanceSettings.OptimizationMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                
                // Описание выбранного режима
                Text(viewModel.settings.optimizationMode.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Cache Settings Section
    
    private var cacheSettingsSection: some View {
        SettingsSection(title: "Cache Settings", icon: "externaldrive") {
            VStack(spacing: 16) {
                HStack {
                    Text("Max Cache Size")
                    Spacer()
                    Text("\(viewModel.settings.maxCacheSize)")
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: Binding(
                        get: { Double(viewModel.settings.maxCacheSize) },
                        set: { viewModel.settings.maxCacheSize = Int($0) }
                    ),
                    in: 10...200,
                    step: 10
                ) {
                    Text("Cache Size")
                } minimumValueLabel: {
                    Text("10")
                        .font(.caption)
                } maximumValueLabel: {
                    Text("200")
                        .font(.caption)
                }
                
                HStack {
                    Text("Estimated Memory Usage:")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(Double(viewModel.settings.maxCacheSize) * 2.5)) MB")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Texture Settings Section
    
    private var textureSettingsSection: some View {
        SettingsSection(title: "Texture Management", icon: "photo.stack") {
            VStack(spacing: 12) {
                Toggle("Enable Texture Pooling", isOn: $viewModel.settings.enableTexturePooling)
                
                if viewModel.settings.enableTexturePooling {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Pool Efficiency")
                            Spacer()
                            Text("85%") // Здесь можно добавить реальную статистику
                                .foregroundColor(.green)
                        }
                        .font(.caption)
                        
                        HStack {
                            Text("Memory Pressure")
                            Spacer()
                            Text("Low") // Здесь можно добавить реальную статистику
                                .foregroundColor(.green)
                        }
                        .font(.caption)
                    }
                    .padding(.leading, 20)
                }
            }
        }
    }
    
    // MARK: - Processing Settings Section
    
    private var processingSettingsSection: some View {
        SettingsSection(title: "Processing", icon: "cpu") {
            VStack(spacing: 12) {
                Toggle("Enable Async Processing", isOn: $viewModel.settings.enableAsyncProcessing)
                Toggle("Enable Adaptive Performance", isOn: $viewModel.settings.enableAdaptivePerformance)
                
                if viewModel.settings.enableAdaptivePerformance {
                    HStack {
                        Text("Current Mode:")
                        Spacer()
                        Text(viewModel.settings.optimizationMode.rawValue)
                            .foregroundColor(.blue)
                    }
                    .font(.caption)
                    .padding(.leading, 20)
                }
            }
        }
    }
    
    // MARK: - Monitoring Section
    
    private var monitoringSection: some View {
        SettingsSection(title: "System Monitoring", icon: "chart.line.uptrend.xyaxis") {
            VStack(spacing: 12) {
                Toggle("Enable System Monitoring", isOn: $viewModel.settings.enableSystemMonitoring)
                
                if viewModel.settings.enableSystemMonitoring {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Thermal State")
                            Spacer()
                            HStack {
                                Image(systemName: viewModel.currentStats.thermalState.icon)
                                    .foregroundColor(viewModel.currentStats.thermalState.color)
                                Text(viewModel.currentStats.thermalState.rawValue)
                                    .foregroundColor(viewModel.currentStats.thermalState.color)
                            }
                        }
                        .font(.caption)
                        
                        HStack {
                            Text("Frame Rate")
                            Spacer()
                            Text("\(Int(viewModel.currentStats.frameRate)) FPS")
                                .foregroundColor(.blue)
                        }
                        .font(.caption)
                    }
                    .padding(.leading, 20)
                }
            }
        }
    }
    
    // MARK: - Performance Stats Section
    
    private var performanceStatsSection: some View {
        SettingsSection(title: "Performance Statistics", icon: "chart.bar.fill") {
            VStack(spacing: 12) {
                HStack {
                    Text("Memory Usage")
                    Spacer()
                    Text("\(String(format: "%.1f", viewModel.currentStats.memoryUsageMB)) MB")
                        .foregroundColor(.blue)
                }
                
                ProgressView(value: viewModel.currentStats.memoryUsageMB / Double(viewModel.systemInfo.availableMemoryMB))
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                
                HStack {
                    Text("GPU Utilization")
                    Spacer()
                    Text("\(Int(viewModel.currentStats.gpuUtilization * 100))%")
                        .foregroundColor(.green)
                }
                
                ProgressView(value: viewModel.currentStats.gpuUtilization)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
            }
        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        SettingsSection(title: "Actions", icon: "gear") {
            VStack(spacing: 12) {
                Button("Reset to Defaults") {
                    viewModel.showResetConfirmation = true
                }
                .foregroundColor(.red)
                
                HStack {
                    Button("Export Settings") {
                        let settings = viewModel.exportSettings()
                        // Здесь можно добавить сохранение в файл
                        print("📄 Exported settings:\n\(settings)")
                    }
                    
                    Button("Import Settings") {
                        // Здесь можно добавить загрузку из файла
                        print("📄 Import settings functionality")
                    }
                }
                
                if viewModel.isApplyingSettings {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Applying settings...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

/// Секция настроек с заголовком и иконкой
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            content
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

/// Строка информации
