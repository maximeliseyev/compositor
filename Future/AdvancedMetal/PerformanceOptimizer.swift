import Foundation
import Metal
import MetalPerformanceShaders
import CoreImage
import os.log

/// Advanced performance optimizer that adapts processing strategies in real-time
/// Leverages Apple's unified memory architecture and thermal management
@MainActor
class PerformanceOptimizer: ObservableObject {
    
    // MARK: - Optimization Strategy
    enum OptimizationTarget {
        case speed          // Minimize processing time
        case quality        // Maximize output quality  
        case efficiency     // Balance speed/quality/power
        case battery        // Optimize for battery life
    }
    
    enum SystemTier {
        case ultraHigh      // M3 Pro/Max/Ultra
        case high           // M1/M2 Pro/Max  
        case balanced       // Base M1/M2
        case efficient      // Intel/compatibility
        
        var recommendedPixelFormat: MTLPixelFormat {
            switch self {
            case .ultraHigh, .high: return .rgba16Float
            case .balanced, .efficient: return .rgba8Unorm
            }
        }
        
        var maxConcurrentOperations: Int {
            switch self {
            case .ultraHigh: return 12
            case .high: return 8
            case .balanced: return 6
            case .efficient: return 4
            }
        }
        
        var supportsAdvancedMPS: Bool {
            switch self {
            case .ultraHigh, .high: return true
            case .balanced, .efficient: return false
            }
        }
    }
    
    // MARK: - System State
    private let device: MTLDevice
    private let mpsProcessor: MPSProcessor
    @Published var currentTier: SystemTier
    @Published var optimizationTarget: OptimizationTarget = .efficiency
    
    // MARK: - Real-time Metrics
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    @Published var memoryPressure: Float = 0.0
    @Published var averageFrameTime: TimeInterval = 0.0
    @Published var gpuUtilization: Float = 0.0
    
    // MARK: - Performance History
    private var performanceMetrics: [PerformanceMetric] = []
    private let maxHistorySize = 200
    private var adaptiveTimer: Timer?
    
    // MARK: - Unified Memory Optimization
    private var texturePool: [MTLPixelFormat: [MTLTexture]] = [:]
    private let texturePoolLock = NSLock()
    private var maxPoolSize: Int { currentTier.maxConcurrentOperations * 4 }
    
    // MARK: - Initialization
    init(device: MTLDevice, mpsProcessor: MPSProcessor) {
        self.device = device
        self.mpsProcessor = mpsProcessor
        self.currentTier = Self.detectSystemTier(device: device)
        
        setupPerformanceMonitoring()
        initializeTexturePool()
        
        print("🧠 Performance Optimizer initialized")
        print("📊 System Tier: \(currentTier)")
        print("🎯 Target: \(optimizationTarget)")
    }
    
    // MARK: - System Detection
    
    private static func detectSystemTier(device: MTLDevice) -> SystemTier {
        let deviceName = device.name.lowercased()
        
        // Apple Silicon detection with more granular tiers
        if deviceName.contains("m3") {
            if deviceName.contains("ultra") { return .ultraHigh }
            if deviceName.contains("max") { return .ultraHigh }
            if deviceName.contains("pro") { return .high }
            return .high
        }
        
        if deviceName.contains("m2") {
            if deviceName.contains("ultra") { return .ultraHigh }
            if deviceName.contains("max") { return .high }
            if deviceName.contains("pro") { return .high }
            return .balanced
        }
        
        if deviceName.contains("m1") {
            if deviceName.contains("ultra") { return .high }
            if deviceName.contains("max") { return .high }
            if deviceName.contains("pro") { return .balanced }
            return .balanced
        }
        
        // Intel/AMD GPUs
        if device.isLowPower {
            return .efficient
        } else {
            return .balanced
        }
    }
    
    // MARK: - Intelligent Strategy Selection
    
    func selectOptimalStrategy(for operation: OperationType, 
                              imageSize: CGSize,
                              quality: ProcessingQuality = .balanced) -> ProcessingPath {
        
        let imageComplexity = calculateImageComplexity(size: imageSize)
        let systemLoad = getCurrentSystemLoad()
        
        // Thermal throttling check
        if thermalState == .critical {
            return .coreImageFallback
        }
        
        // Memory pressure check
        if memoryPressure > 0.85 {
            return selectMemoryConstrainedStrategy(operation: operation, imageSize: imageSize)
        }
        
        // Select based on optimization target
        switch optimizationTarget {
        case .speed:
            return selectSpeedOptimizedStrategy(operation: operation, 
                                              imageComplexity: imageComplexity,
                                              systemLoad: systemLoad)
        case .quality:
            return selectQualityOptimizedStrategy(operation: operation,
                                                imageComplexity: imageComplexity)
        case .efficiency:
            return selectBalancedStrategy(operation: operation,
                                        imageComplexity: imageComplexity,
                                        systemLoad: systemLoad)
        case .battery:
            return selectBatteryOptimizedStrategy(operation: operation)
        }
    }
    
    private func selectSpeedOptimizedStrategy(operation: OperationType, 
                                            imageComplexity: Double,
                                            systemLoad: Double) -> ProcessingPath {
        
        // For speed, prefer MPS when available, custom Metal for specialized operations
        if currentTier.supportsAdvancedMPS && isMPSOptimal(for: operation) {
            return .metalPerformanceShaders
        }
        
        if systemLoad < 0.7 && imageComplexity > 0.5 {
            return .customMetalShaders
        }
        
        return .coreImageOptimized
    }
    
    private func selectQualityOptimizedStrategy(operation: OperationType,
                                              imageComplexity: Double) -> ProcessingPath {
        
        // For quality, prefer custom shaders with high precision
        if currentTier == .ultraHigh && operation.supportsCustomShaders {
            return .customMetalShaders
        }
        
        if currentTier.supportsAdvancedMPS && isMPSOptimal(for: operation) {
            return .metalPerformanceShaders
        }
        
        return .coreImageOptimized
    }
    
    private func selectBalancedStrategy(operation: OperationType,
                                      imageComplexity: Double,
                                      systemLoad: Double) -> ProcessingPath {
        
        // Intelligent hybrid approach
        let mpsScore = calculateMPSScore(operation: operation, complexity: imageComplexity)
        let metalScore = calculateCustomMetalScore(operation: operation, systemLoad: systemLoad)
        let ciScore = calculateCoreImageScore(operation: operation, systemLoad: systemLoad)
        
        let maxScore = max(mpsScore, metalScore, ciScore)
        
        if maxScore == mpsScore && mpsScore > 0.6 {
            return .metalPerformanceShaders
        } else if maxScore == metalScore && metalScore > 0.5 {
            return .customMetalShaders
        } else {
            return .coreImageOptimized
        }
    }
    
    private func selectBatteryOptimizedStrategy(operation: OperationType) -> ProcessingPath {
        // For battery optimization, prefer Core Image or efficient MPS operations
        if isMPSOptimal(for: operation) && operation.isLowPower {
            return .metalPerformanceShaders
        }
        return .coreImageOptimized
    }
    
    private func selectMemoryConstrainedStrategy(operation: OperationType, 
                                               imageSize: CGSize) -> ProcessingPath {
        // Under memory pressure, use most memory-efficient approach
        let pixelCount = imageSize.width * imageSize.height
        
        if pixelCount > 4_000_000 { // > 4MP
            return .coreImageOptimized  // Let Core Image handle memory management
        }
        
        if isMPSOptimal(for: operation) {
            return .metalPerformanceShaders  // MPS is generally memory efficient
        }
        
        return .coreImageOptimized
    }
    
    // MARK: - Scoring Functions
    
    private func calculateMPSScore(operation: OperationType, complexity: Double) -> Double {
        guard currentTier.supportsAdvancedMPS else { return 0.0 }
        
        var score = 0.0
        
        // MPS excels at standard operations
        switch operation {
        case .blur, .convolution: score += 0.9
        case .morphology: score += 0.8
        case .colorCorrection: score += 0.6
        case .customEffect: score += 0.3
        case .neuralProcessing: score += 0.7
        }
        
        // Bonus for complex images (MPS scales well)
        score += complexity * 0.2
        
        // Penalty for thermal throttling
        if thermalState != .nominal {
            score *= 0.7
        }
        
        return min(1.0, score)
    }
    
    private func calculateCustomMetalScore(operation: OperationType, systemLoad: Double) -> Double {
        var score = 0.0
        
        // Custom Metal excels at specialized operations
        switch operation {
        case .customEffect: score += 0.9
        case .colorCorrection: score += 0.8
        case .convolution: score += 0.7
        case .blur: score += 0.6
        case .morphology: score += 0.5
        case .neuralProcessing: score += 0.4
        }
        
        // Bonus for high-end hardware
        switch currentTier {
        case .ultraHigh: score += 0.2
        case .high: score += 0.1
        case .balanced: score += 0.0
        case .efficient: score -= 0.2
        }
        
        // Penalty for high system load
        score -= systemLoad * 0.3
        
        return max(0.0, min(1.0, score))
    }
    
    private func calculateCoreImageScore(operation: OperationType, systemLoad: Double) -> Double {
        var score = 0.4 // Base reliability score
        
        // Core Image is always available and reliable
        score += 0.3
        
        // Bonus for high system load (Core Image handles resource management)
        if systemLoad > 0.8 {
            score += 0.2
        }
        
        // Bonus for memory pressure (Core Image is memory efficient)
        if memoryPressure > 0.7 {
            score += 0.2
        }
        
        return min(1.0, score)
    }
    
    // MARK: - Unified Memory Optimization
    
    private func initializeTexturePool() {
        texturePoolLock.lock()
        defer { texturePoolLock.unlock() }
        
        // Pre-allocate common texture formats
        let commonFormats: [MTLPixelFormat] = [
            currentTier.recommendedPixelFormat,
            .rgba8Unorm,
            .rgba16Float
        ]
        
        for format in commonFormats {
            texturePool[format] = []
        }
    }
    
    func acquireTexture(width: Int, height: Int, pixelFormat: MTLPixelFormat) -> MTLTexture? {
        texturePoolLock.lock()
        defer { texturePoolLock.unlock() }
        
        // Try to reuse from pool
        if let pool = texturePool[pixelFormat], !pool.isEmpty {
            for (index, texture) in pool.enumerated() {
                if texture.width == width && texture.height == height {
                    texturePool[pixelFormat]?.remove(at: index)
                    return texture
                }
            }
        }
        
        // Create new texture
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .shared  // Unified memory optimization
        
        return device.makeTexture(descriptor: descriptor)
    }
    
    func releaseTexture(_ texture: MTLTexture) {
        texturePoolLock.lock()
        defer { texturePoolLock.unlock() }
        
        let format = texture.pixelFormat
        if texturePool[format] == nil {
            texturePool[format] = []
        }
        
        // Only pool if we haven't exceeded limit
        if let pool = texturePool[format], pool.count < maxPoolSize {
            texturePool[format]?.append(texture)
        }
        // Otherwise let it deallocate naturally
    }
    
    // MARK: - Performance Monitoring
    
    private func setupPerformanceMonitoring() {
        // Monitor system metrics every 2 seconds
        adaptiveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSystemMetrics()
                self?.adaptOptimizationStrategy()
            }
        }
    }
    
    private func updateSystemMetrics() {
        // Update thermal state
        thermalState = ProcessInfo.processInfo.thermalState
        
        // Update memory pressure
        let currentMemory = device.currentAllocatedSize
        let maxMemory = device.recommendedMaxWorkingSetSize
        memoryPressure = Float(currentMemory) / Float(maxMemory)
        
        // Estimate GPU utilization (simplified)
        gpuUtilization = min(1.0, memoryPressure * 1.2)
        
        // Update average frame time from recent metrics
        if !performanceMetrics.isEmpty {
            let recentMetrics = performanceMetrics.suffix(10)
            averageFrameTime = recentMetrics.map(\.processingTime).reduce(0, +) / Double(recentMetrics.count)
        }
    }
    
    private func adaptOptimizationStrategy() {
        // Adaptive optimization based on performance history
        let recentMetrics = performanceMetrics.suffix(20)
        guard !recentMetrics.isEmpty else { return }
        
        let errorRate = Double(recentMetrics.filter { $0.hadError }.count) / Double(recentMetrics.count)
        let avgTime = recentMetrics.map(\.processingTime).reduce(0, +) / Double(recentMetrics.count)
        
        // If error rate is high, become more conservative
        if errorRate > 0.15 {
            optimizationTarget = .efficiency
        }
        
        // If performance is poor and thermal state is good, try speed optimization
        if avgTime > 0.05 && thermalState == .nominal && memoryPressure < 0.6 {
            optimizationTarget = .speed
        }
        
        // If thermal throttling, prioritize battery
        if thermalState == .serious || thermalState == .critical {
            optimizationTarget = .battery
        }
    }
    
    // MARK: - Utility Methods
    
    private func calculateImageComplexity(size: CGSize) -> Double {
        let pixelCount = size.width * size.height
        // Normalize to 0-1 scale where 4K ≈ 0.5, 8K ≈ 1.0
        return min(1.0, pixelCount / (7680 * 4320))
    }
    
    private func getCurrentSystemLoad() -> Double {
        // Simplified system load estimation
        let thermalFactor = thermalState == .nominal ? 0.0 : 0.4
        let memoryFactor = Double(memoryPressure) * 0.5
        return min(1.0, thermalFactor + memoryFactor)
    }
    
    private func isMPSOptimal(for operation: OperationType) -> Bool {
        guard currentTier.supportsAdvancedMPS else { return false }
        
        switch operation {
        case .blur, .convolution, .morphology:
            return true
        case .colorCorrection:
            return device.supportsFamily(.apple4)
        case .neuralProcessing:
            return device.supportsFamily(.apple7)
        case .customEffect:
            return false
        }
    }
    
    // MARK: - Performance Recording
    
    func recordPerformance(_ metric: PerformanceMetric) {
        performanceMetrics.append(metric)
        
        // Keep history manageable
        if performanceMetrics.count > maxHistorySize {
            performanceMetrics.removeFirst()
        }
    }
    
    // MARK: - Debug Information
    
    func getOptimizationInfo() -> String {
        return """
        🧠 Performance Optimizer Status:
           System Tier: \(currentTier)
           Optimization Target: \(optimizationTarget)
           
        📊 Real-time Metrics:
           Thermal State: \(thermalState.description)
           Memory Pressure: \(String(format: "%.1f", memoryPressure * 100))%
           GPU Utilization: \(String(format: "%.1f", gpuUtilization * 100))%
           Average Frame Time: \(String(format: "%.2f", averageFrameTime * 1000))ms
           
        🔧 Unified Memory:
           Texture Pool Size: \(texturePool.values.map { $0.count }.reduce(0, +)) textures
           Max Pool Size: \(maxPoolSize)
           
        📈 Performance History: \(performanceMetrics.count) metrics
        """
    }
    
    deinit {
        adaptiveTimer?.invalidate()
    }
}

// MARK: - Supporting Types

enum ProcessingPath: String, CaseIterable {
    case metalPerformanceShaders = "Metal Performance Shaders"
    case customMetalShaders = "Custom Metal Shaders"
    case coreImageOptimized = "Core Image Optimized"
    case coreImageFallback = "Core Image Fallback"
    
    var description: String {
        switch self {
        case .metalPerformanceShaders: return "Optimized Apple GPU acceleration"
        case .customMetalShaders: return "Specialized GPU compute shaders"
        case .coreImageOptimized: return "Optimized Core Image pipeline"
        case .coreImageFallback: return "Safe Core Image fallback"
        }
    }
}

enum ProcessingQuality: String, CaseIterable {
    case draft = "Draft"
    case balanced = "Balanced"
    case high = "High"
    case maximum = "Maximum"
}

extension OperationType {
    var supportsCustomShaders: Bool {
        switch self {
        case .customEffect, .colorCorrection, .convolution: return true
        case .blur, .morphology, .neuralProcessing: return false
        }
    }
    
    var isLowPower: Bool {
        switch self {
        case .blur, .colorCorrection: return true
        case .convolution, .morphology, .customEffect, .neuralProcessing: return false
        }
    }
}

extension ProcessInfo.ThermalState {
    var description: String {
        switch self {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}
