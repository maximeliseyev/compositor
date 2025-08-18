import Foundation
import Metal
import CoreImage
import os.log

// MARK: - Strategy Types

enum ProcessingStrategy: String, CaseIterable {
    case metalMPS = "Metal Performance Shaders"      // Preferred for supported operations
    case metalCustom = "Custom Metal Shaders"       // For specialized effects
    case coreImage = "Core Image"                    // Fallback and compatibility
    case hybrid = "Hybrid Processing"               // Intelligent mixing
    
    var priority: Int {
        switch self {
        case .metalMPS: return 4      // Highest performance for supported ops
        case .metalCustom: return 3   // High performance for custom effects
        case .hybrid: return 2        // Balanced approach
        case .coreImage: return 1     // Reliable fallback
        }
    }
}

enum ProcessingTier: String, CaseIterable {
    case ultraHigh = "Ultra High"    // M3 Pro/Max/Ultra with Neural Engine
    case high = "High"               // M1/M2 Pro/Max
    case balanced = "Balanced"       // Base M1/M2, Intel with discrete GPU
    case efficient = "Efficient"    // Intel integrated, compatibility mode
    
    var maxConcurrentOperations: Int {
        switch self {
        case .ultraHigh: return 8
        case .high: return 6
        case .balanced: return 4
        case .efficient: return 2
        }
    }
    
    var preferredPixelFormat: MTLPixelFormat {
        switch self {
        case .ultraHigh, .high: return .rgba16Float  // Higher precision
        case .balanced, .efficient: return .rgba8Unorm  // Performance over precision
        }
    }
}

/// Intelligent processing strategy selection based on system capabilities and load
@MainActor
class ProcessingStrategyManager: ObservableObject {
    

    
    // MARK: - System Information
    private let device: MTLDevice
    private let systemInfo: SystemInfo
    @Published var currentTier: ProcessingTier
    @Published var recommendedStrategy: ProcessingStrategy
    
    // MARK: - Performance Monitoring
    @Published var averageProcessingTime: TimeInterval = 0.0
    @Published var gpuUtilization: Double = 0.0
    @Published var memoryPressure: Float = 0.0
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    
    private var performanceHistory: [PerformanceMetric] = []
    private let maxHistorySize = 100
    
    // MARK: - Initialization
    init(device: MTLDevice) {
        self.device = device
        self.systemInfo = SystemInfo(device: device)
        let tier = ProcessingStrategyManager.determineTier(for: device)
        self.currentTier = tier
        self.recommendedStrategy = ProcessingStrategyManager.determineInitialStrategy(for: tier)
        
        startPerformanceMonitoring()
        
        print("🧠 Processing Strategy Manager initialized")
        print("📊 System Tier: \(currentTier.rawValue)")
        print("⚡ Recommended Strategy: \(recommendedStrategy.rawValue)")
    }
    
    // MARK: - Strategy Selection
    
    /// Select optimal processing strategy for a specific operation
    func selectStrategy(for operation: OperationType, 
                       imageSize: CGSize, 
                       complexity: OperationComplexity = .medium) -> ProcessingStrategy {
        
        // Consider current system state
        let systemLoad = getCurrentSystemLoad()
        let availableMemory = getAvailableGPUMemory()
        let imageComplexity = calculateImageComplexity(size: imageSize)
        
        // MPS availability check
        let mpsSupported = isMPSSupported(for: operation)
        
        // Decision matrix
        switch (currentTier, complexity, mpsSupported) {
        case (.ultraHigh, _, true), (.high, .low, true), (.high, .medium, true):
            return .metalMPS
            
        case (.ultraHigh, .high, false), (.high, .high, false):
            return .metalCustom
            
        case (.balanced, _, true) where systemLoad < 0.7:
            return .metalMPS
            
        case (.balanced, _, _) where systemLoad < 0.8:
            return .metalCustom
            
        case (.efficient, _, _), 
            (_, _, _) where systemLoad > 0.9:
            return .coreImage
            
        default:
            return .hybrid
        }
    }
    
    /// Adaptive strategy that changes based on performance feedback
    func adaptiveStrategy(for operation: OperationType, 
                         imageSize: CGSize,
                         previousPerformance: [PerformanceMetric]) -> ProcessingStrategy {
        
        let baseStrategy = selectStrategy(for: operation, imageSize: imageSize)
        
        // Analyze recent performance
        let recentMetrics = previousPerformance.suffix(10)
        let averageTime = recentMetrics.map(\.processingTime).reduce(0, +) / Double(recentMetrics.count)
        let errorRate = Double(recentMetrics.filter { $0.hadError }.count) / Double(recentMetrics.count)
        
        // Adjust strategy based on performance
        if errorRate > 0.2 {
            // High error rate - fallback to more reliable strategy
            return baseStrategy.priority > ProcessingStrategy.coreImage.priority ? 
                   ProcessingStrategy.coreImage : baseStrategy
        }
        
        if averageTime > getTargetProcessingTime(for: operation, imageSize: imageSize) * 1.5 {
            // Too slow - try more efficient strategy
            return optimizeForSpeed(baseStrategy)
        }
        
        if averageTime < getTargetProcessingTime(for: operation, imageSize: imageSize) * 0.5 {
            // Very fast - we can afford higher quality
            return optimizeForQuality(baseStrategy)
        }
        
        return baseStrategy
    }
    
    // MARK: - System Analysis
    
    private static func determineTier(for device: MTLDevice) -> ProcessingTier {
        let deviceName = device.name.lowercased()
        
        // Apple Silicon detection
        if deviceName.contains("m3") {
            if deviceName.contains("ultra") { return .ultraHigh }
            if deviceName.contains("max") || deviceName.contains("pro") { return .ultraHigh }
            return .high
        }
        
        if deviceName.contains("m2") {
            if deviceName.contains("ultra") { return .ultraHigh }
            if deviceName.contains("max") || deviceName.contains("pro") { return .high }
            return .high
        }
        
        if deviceName.contains("m1") {
            if deviceName.contains("ultra") { return .high }
            if deviceName.contains("max") || deviceName.contains("pro") { return .high }
            return .balanced
        }
        
        // Intel Mac detection
        if deviceName.contains("radeon") || deviceName.contains("nvidia") {
            return .balanced
        }
        
        // Integrated graphics
        return .efficient
    }
    
    private static func determineInitialStrategy(for tier: ProcessingTier) -> ProcessingStrategy {
        switch tier {
        case .ultraHigh: return .metalMPS
        case .high: return .metalMPS
        case .balanced: return .hybrid
        case .efficient: return .coreImage
        }
    }
    
    // MARK: - Performance Monitoring
    
    private func startPerformanceMonitoring() {
        // Monitor system performance every 5 seconds
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSystemMetrics()
            }
        }
    }
    
    private func updateSystemMetrics() {
        // Update thermal state
        thermalState = ProcessInfo.processInfo.thermalState
        
        // Update memory pressure (simplified)
        memoryPressure = Float(device.currentAllocatedSize) / Float(device.recommendedMaxWorkingSetSize)
        
        // Estimate GPU utilization (this is simplified - real implementation would use IOKit)
        gpuUtilization = min(1.0, Double(memoryPressure) * 1.2)
        
        // Adjust strategy if needed
        if thermalState == .critical || memoryPressure > 0.9 {
            recommendedStrategy = .coreImage  // Conservative approach
        } else if thermalState == .nominal && memoryPressure < 0.5 {
            recommendedStrategy = ProcessingStrategyManager.determineInitialStrategy(for: currentTier)
        }
    }
    
    // MARK: - Utility Methods
    
    private func getCurrentSystemLoad() -> Double {
        // Simplified system load calculation
        let cpuUsage = ProcessInfo.processInfo.systemUptime > 0 ? 0.3 : 0.1  // Placeholder
        let memoryUsage = Double(memoryPressure)
        let thermalFactor = thermalState == .nominal ? 0.0 : 0.3
        
        return min(1.0, cpuUsage + memoryUsage + thermalFactor)
    }
    
    private func getAvailableGPUMemory() -> Int64 {
        let maxMemory = Int64(device.recommendedMaxWorkingSetSize)
        let currentMemory = Int64(device.currentAllocatedSize)
        return maxMemory - currentMemory
    }
    
    private func calculateImageComplexity(size: CGSize) -> Double {
        let pixelCount = size.width * size.height
        // Normalize to 0-1 scale where 4K = 0.5, 8K = 1.0
        return min(1.0, pixelCount / (7680 * 4320)) // 8K resolution
    }
    
    private func isMPSSupported(for operation: OperationType) -> Bool {
        switch operation {
        case .blur, .convolution, .morphology:
            return true
        case .colorCorrection, .customEffect:
            return device.supportsFamily(.apple4)
        case .neuralProcessing:
            return device.supportsFamily(.apple7) // Neural Engine support
        }
    }
    
    private func getTargetProcessingTime(for operation: OperationType, imageSize: CGSize) -> TimeInterval {
        let baseTime: TimeInterval = 0.016 // Target 60fps = 16ms
        let complexityMultiplier = calculateImageComplexity(size: imageSize) + 1.0
        
        switch operation {
        case .blur: return baseTime * complexityMultiplier * 0.5
        case .convolution: return baseTime * complexityMultiplier * 0.8
        case .colorCorrection: return baseTime * complexityMultiplier * 0.3
        case .morphology: return baseTime * complexityMultiplier * 0.6
        case .customEffect: return baseTime * complexityMultiplier * 1.2
        case .neuralProcessing: return baseTime * complexityMultiplier * 2.0
        }
    }
    
    private func optimizeForSpeed(_ strategy: ProcessingStrategy) -> ProcessingStrategy {
        switch strategy {
        case .metalMPS: return .metalMPS  // Already optimal
        case .metalCustom: return .metalMPS
        case .hybrid: return .metalCustom
        case .coreImage: return .coreImage  // Can't optimize further
        }
    }
    
    private func optimizeForQuality(_ strategy: ProcessingStrategy) -> ProcessingStrategy {
        switch strategy {
        case .coreImage: return .hybrid
        case .hybrid: return .metalCustom
        case .metalCustom: return .metalMPS
        case .metalMPS: return .metalMPS  // Already high quality
        }
    }
    
    // MARK: - Performance Recording
    
    func recordPerformance(_ metric: PerformanceMetric) {
        performanceHistory.append(metric)
        
        // Keep history size manageable
        if performanceHistory.count > maxHistorySize {
            performanceHistory.removeFirst()
        }
        
        // Update running averages
        let recentMetrics = performanceHistory.suffix(10)
        averageProcessingTime = recentMetrics.map(\.processingTime).reduce(0, +) / Double(recentMetrics.count)
    }
    
    // MARK: - Debug Information
    
    func getDebugInfo() -> String {
        return """
        🧠 Processing Strategy Manager:
           Current Tier: \(currentTier.rawValue)
           Recommended Strategy: \(recommendedStrategy.rawValue)
           
        📊 System Metrics:
           GPU Utilization: \(String(format: "%.1f", gpuUtilization * 100))%
           Memory Pressure: \(String(format: "%.1f", memoryPressure * 100))%
           Thermal State: \(thermalState.rawValue)
           Average Processing Time: \(String(format: "%.2f", averageProcessingTime * 1000))ms
           
        🔧 Device Info:
           \(systemInfo.description)
           
        📈 Performance History: \(performanceHistory.count) metrics
        """
    }
}

// MARK: - Supporting Types

enum OperationType: String, CaseIterable {
    case blur = "Blur"
    case convolution = "Convolution"
    case colorCorrection = "Color Correction"
    case morphology = "Morphology"
    case customEffect = "Custom Effect"
    case neuralProcessing = "Neural Processing"
}

enum OperationComplexity: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

struct PerformanceMetric {
    let operation: OperationType
    let strategy: ProcessingStrategy
    let imageSize: CGSize
    let processingTime: TimeInterval
    let memoryUsed: Int64
    let hadError: Bool
    let timestamp: Date = Date()
}

struct SystemInfo {
    let deviceName: String
    let metalVersion: String
    let maxThreadsPerThreadgroup: MTLSize
    let recommendedMaxWorkingSetSize: UInt64
    let supportsFamily: [MTLGPUFamily]
    
    init(device: MTLDevice) {
        self.deviceName = device.name
        self.metalVersion = "Metal 3.0+" // Simplified
        self.maxThreadsPerThreadgroup = device.maxThreadsPerThreadgroup
        self.recommendedMaxWorkingSetSize = device.recommendedMaxWorkingSetSize
        
        // Check supported GPU families
        var families: [MTLGPUFamily] = []
        if device.supportsFamily(.apple1) { families.append(.apple1) }
        if device.supportsFamily(.apple2) { families.append(.apple2) }
        if device.supportsFamily(.apple3) { families.append(.apple3) }
        if device.supportsFamily(.apple4) { families.append(.apple4) }
        if device.supportsFamily(.apple5) { families.append(.apple5) }
        if device.supportsFamily(.apple6) { families.append(.apple6) }
        if device.supportsFamily(.apple7) { families.append(.apple7) }
        self.supportsFamily = families
    }
    
    var description: String {
        return """
        Device: \(deviceName)
        Metal Version: \(metalVersion)
        Max Threads: \(maxThreadsPerThreadgroup.width)×\(maxThreadsPerThreadgroup.height)×\(maxThreadsPerThreadgroup.depth)
        Max Memory: \(recommendedMaxWorkingSetSize / 1024 / 1024) MB
        GPU Families: \(supportsFamily.map { String($0.rawValue) }.joined(separator: ", "))
        """
    }
}

extension ProcessInfo.ThermalState {
    var rawValue: String {
        switch self {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}
