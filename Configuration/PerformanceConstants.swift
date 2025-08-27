//
//  PerformanceConstants.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 12.08.2025.
//

import Foundation
import Metal
import SwiftUI
import Combine

/// Константы производительности для всего приложения
/// Все магические числа должны быть вынесены сюда для централизованного управления
struct PerformanceConstants {
    
    // MARK: - Кэширование
    
    /// Максимальный размер кэша обработанных нод
    static let maxCacheSize = 50
    
    /// Время жизни кэша в секундах
    static let cacheExpirationTime: TimeInterval = 30.0
    
    /// Максимальный размер буфера кадров для видео
    static let maxFrameBufferSize = 100
    
    /// Лимит кэша кадров для InputNode
    static let frameCacheLimit = 30
    
    /// Интервал очистки кэша в секундах
    static let cacheCleanupInterval: TimeInterval = 60.0
    
    // MARK: - Текстуры и Metal
    
    /// Максимальный размер пула текстур
    static let maxTexturePoolSize = 20
    
    /// Интервал очистки текстур в секундах
    static let textureCleanupInterval: TimeInterval = 60.0
    
    /// Максимальная память для текстур в МБ
    static let maxTextureMemoryMB = 512
    
    /// Время жизни текстуры в пуле (секунды)
    static let textureLifetime: TimeInterval = 300.0
    
    /// Количество приоритетных текстур
    static let priorityTexturesCount = 10
    
    /// Количество текстур для предварительной загрузки
    static let texturePreloadCount = 5
    
    /// Порог давления памяти для принудительной очистки
    static let memoryPressureThreshold: Float = 0.8
    
    /// Предпочтительный формат пикселей для Metal
    static let preferredPixelFormat: MTLPixelFormat = .rgba16Float
    
    /// Размер группы потоков для Metal шейдеров
    static let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
    
    /// Максимальное количество одновременных Metal операций
    static let maxConcurrentMetalOperations = 8
    
    // MARK: - Обработка
    
    /// Максимальное количество одновременных операций
    static let maxConcurrentOperations = 8
    
    /// Таймаут обработки в секундах
    static let processingTimeout: TimeInterval = 30.0
    
    /// Таймаут загрузки медиафайла в секундах
    static let mediaLoadTimeout: TimeInterval = 30.0
    
    /// Интервал обновления прогресса обработки в секундах
    static let progressUpdateInterval: TimeInterval = 0.1
    
    // MARK: - UI и отзывчивость
    
    /// Максимальная частота обновлений UI (60 FPS)
    static let maxUpdateFrequency: TimeInterval = 1.0 / 60.0
    
    /// Порог throttling для предотвращения слишком частых обновлений
    static let throttlingThreshold: TimeInterval = 0.016 // 16ms
    
    /// Интервал обновления статистики производительности
    static let statsUpdateInterval: TimeInterval = 2.0
    
    /// Задержка debounce для автоматической обработки графа
    static let graphProcessingDebounce: TimeInterval = 0.3
    
    // MARK: - Системные настройки
    
    /// Порог теплового throttling (0.0 - 1.0)
    static let thermalThrottlingThreshold: Float = 0.8
    
    /// Порог давления памяти для системы (0.0 - 1.0)
    static let systemMemoryPressureThreshold: Float = 0.85
    
    /// Порог оптимизации для батареи (0.0 - 1.0)
    static let batteryOptimizationThreshold: Float = 0.2
    
    /// Минимальный уровень заряда батареи для оптимизации (0.0 - 1.0)
    static let minimumBatteryLevel: Float = 0.15
    
    // MARK: - Видео и медиа
    
    /// Максимальное количество кадров для предварительного просмотра
    static let maxPreviewFrames = 10
    
    /// Интервал между кадрами при воспроизведении (60 FPS)
    static let frameInterval: TimeInterval = 1.0 / 60.0
    
    /// Таймаут извлечения кадров в секундах
    static let frameExtractionTimeout: TimeInterval = 30.0
    
    /// Максимальный размер файла для предварительного просмотра (в байтах)
    static let maxPreviewFileSize: Int64 = 100 * 1024 * 1024 // 100 MB
    
    /// Максимальный размер кэша кадров видео
    static let videoFrameCacheSize = 50
    
    /// Оценочная частота кадров для извлечения (FPS)
    static let defaultVideoFrameRate: Double = 30.0
    
    /// Предпочитаемый таймскейл для видео операций
    static let preferredVideoTimescale: Int32 = 600
    
    /// Интервал ожидания при загрузке видео (наносекунды)
    static let videoLoadWaitInterval: UInt64 = 100_000_000 // 0.1 секунды
    
    // MARK: - UI и интерфейс
    
    /// Размеры нод
    static let nodeWidth: CGFloat = 80
    static let nodeHeight: CGFloat = 40
    
    /// Размеры портов
    static let portSize: CGFloat = 10
    static let portSpacing: CGFloat = 20
    static let portVerticalOffset: CGFloat = 10
    
    /// Отступы и радиусы
    static let nodeSelectionPadding: CGFloat = 20
    static let nodeCornerRadius: CGFloat = 8
    static let connectionLineWidth: CGFloat = 3
    static let selectionBorderWidth: CGFloat = 2
    
    /// Сетка
    static let gridSpacing: CGFloat = 40
    
    /// Масштабирование UI
    static let defaultUIScale: CGFloat = 1.0
    
    /// Размеры тестовых текстур
    static let smallTestTextureSize = 64
    static let mediumTestTextureSize = 128
    static let standardTestTextureSize = 256
    static let largeTestTextureSize = 512
    static let extraLargeTestTextureSize = 1024
    static let ultraLargeTestTextureSize = 4096
    
    // MARK: - Популярные разрешения
    
    /// HD разрешение
    static let hdWidth = 1280
    static let hdHeight = 720
    
    /// Full HD разрешение
    static let fullHDWidth = 1920
    static let fullHDHeight = 1080
    
    /// 2K разрешение
    static let twoKWidth = 2560
    static let twoKHeight = 1440
    
    /// 4K разрешение
    static let fourKWidth = 3840
    static let fourKHeight = 2160
    
    /// 540p разрешение
    static let lowResWidth = 960
    static let lowResHeight = 540
    
    // MARK: - Безопасность и ошибки
    
    /// Максимальное количество попыток повторной обработки
    static let maxRetryAttempts = 3
    
    /// Задержка между попытками повторной обработки в секундах
    static let retryDelay: TimeInterval = 1.0
    
    /// Таймаут для операций с файловой системой в секундах
    static let fileSystemTimeout: TimeInterval = 10.0
    
    // MARK: - Отладка и профилирование
    
    /// Включить подробное логирование в DEBUG режиме
    static let enableVerboseLogging = true
    
    /// Максимальное количество записей в логе производительности
    static let maxPerformanceLogEntries = 1000
    
    /// Интервал записи метрик производительности
    static let performanceMetricsInterval: TimeInterval = 5.0
    
    // MARK: - Адаптивные настройки
    
    /// Коэффициент адаптации производительности (0.1 - 2.0)
    static let performanceAdaptationFactor: Float = 1.0
    
    /// Минимальный FPS для плавной работы UI
    static let minimumFPS: Float = 30.0
    
    /// Целевой FPS для оптимальной производительности
    static let targetFPS: Float = 60.0
    
    /// Максимальный FPS для высокопроизводительных устройств
    static let maximumFPS: Float = 120.0
    
    // MARK: - Шейдеры и цветокоррекция
    
    /// Значения по умолчанию для цветокоррекции
    static let defaultExposure: Float = 0.0
    static let defaultContrast: Float = 1.0
    static let defaultSaturation: Float = 1.0
    static let defaultBrightness: Float = 0.0
    static let defaultGamma: Float = 1.0
    static let defaultTemperature: Float = 0.0
    
    /// Множители для цветовых каналов
    static let redChannelWeight: Float = 0.299
    static let greenChannelWeight: Float = 0.587
    static let blueChannelWeight: Float = 0.114
    
    /// Константы для температуры цвета
    static let temperatureMultiplier: Float = 0.1
    static let temperatureRedBoost: Float = 1.0
    static let temperatureBlueDamping: Float = 0.5
    
    /// Константы для блендинга
    static let blendMidpoint: Float = 0.5
    static let blendExponent: Float = 2.0
    
    /// Размеры буферов для шейдеров
    static let blurParamsSize = 32 // Размер BlurParams в байтах
    static let colorCorrectionParamsSize = 64 // Размер ColorCorrectionParams в байтах
    
    // MARK: - Тестовые константы
    
    /// Константы для тестирования
    static let testIterationCount = 10
    static let testLargeIterationCount = 20
    static let testSmallIterationCount = 5
    static let testTimeoutSeconds: TimeInterval = 5.0
    static let testLongTimeoutSeconds: TimeInterval = 10.0
    static let testPerformanceTimeoutSeconds: TimeInterval = 15.0
    
    /// Тестовые цвета
    static let testColorRed: Float = 0.5
    static let testColorGreen: Float = 0.3
    static let testColorBlue: Float = 0.8
    static let testColorAlpha: Float = 1.0
    
    /// Пороги для тестов производительности
    static let testMinReuseRatio: Double = 0.0
    static let testMaxMemoryUsage: Double = 0.0
    static let testMinPoolSize = 0
    static let testMaxPoolSize = 1
}

// MARK: - Настройки производительности

/// Настраиваемые параметры производительности
@MainActor
public class PerformanceSettings: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Режим оптимизации производительности
    @Published var optimizationMode: OptimizationMode = .balanced
    
    /// Максимальный размер кэша
    @Published var maxCacheSize: Int = PerformanceConstants.maxCacheSize
    
    /// Включить пул текстур
    @Published var enableTexturePooling: Bool = true
    
    /// Включить асинхронную обработку
    @Published var enableAsyncProcessing: Bool = true
    
    /// Включить адаптивную производительность
    @Published var enableAdaptivePerformance: Bool = true
    
    /// Включить мониторинг системных ресурсов
    @Published var enableSystemMonitoring: Bool = true
    
    // MARK: - Enums
    
    /// Режимы оптимизации производительности
    enum OptimizationMode: String, CaseIterable {
        case speed = "Speed"
        case quality = "Quality"
        case balanced = "Balanced"
        case battery = "Battery"
        
        var description: String {
            switch self {
            case .speed:
                return "Максимальная скорость обработки"
            case .quality:
                return "Максимальное качество результата"
            case .balanced:
                return "Сбалансированная производительность"
            case .battery:
                return "Оптимизация для батареи"
            }
        }
        
        var maxConcurrentOperations: Int {
            switch self {
            case .speed: return 12
            case .quality: return 6
            case .balanced: return 8
            case .battery: return 4
            }
        }
        
        var preferredPixelFormat: MTLPixelFormat {
            switch self {
            case .speed, .balanced: return .rgba8Unorm
            case .quality: return .rgba16Float
            case .battery: return .rgba8Unorm
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Применяет настройки на основе выбранного режима оптимизации
    func applyModeSettings() {
        switch optimizationMode {
        case .speed:
            maxCacheSize = PerformanceConstants.maxCacheSize * 2
            enableTexturePooling = true
            enableAsyncProcessing = true
            enableAdaptivePerformance = false
            enableSystemMonitoring = false
        case .quality:
            maxCacheSize = PerformanceConstants.maxCacheSize
            enableTexturePooling = true
            enableAsyncProcessing = true
            enableAdaptivePerformance = true
            enableSystemMonitoring = true
        case .balanced:
            maxCacheSize = PerformanceConstants.maxCacheSize
            enableTexturePooling = true
            enableAsyncProcessing = true
            enableAdaptivePerformance = true
            enableSystemMonitoring = true
        case .battery:
            maxCacheSize = PerformanceConstants.maxCacheSize / 2
            enableTexturePooling = false
            enableAsyncProcessing = false
            enableAdaptivePerformance = true
            enableSystemMonitoring = true
        }
    }
    
    // MARK: - Initialization
    
    init() {
        // Загружаем сохраненные настройки
        loadSettings()
    }
    
    // MARK: - Methods
    
    /// Применяет настройки производительности
    func applySettings() {
        // Применяем настройки к системе
        updateSystemSettings()
        
        // Сохраняем настройки
        saveSettings()
    }
    
    /// Сбрасывает настройки к значениям по умолчанию
    func resetToDefaults() {
        optimizationMode = .balanced
        maxCacheSize = PerformanceConstants.maxCacheSize
        enableTexturePooling = true
        enableAsyncProcessing = true
        enableAdaptivePerformance = true
        enableSystemMonitoring = true
        
        applySettings()
    }
    
    // MARK: - Private Methods
    
    private func updateSystemSettings() {
        // TODO: Обновляем настройки Metal рендерера
        // MetalRenderingManager.shared.setPerformanceMode(
        //     MetalRenderingManager.PerformanceMode(rawValue: optimizationMode.rawValue) ?? .balanced
        // )
        
        // Обновляем настройки кэша
        // (здесь можно добавить обновление других компонентов)
    }
    
    private func loadSettings() {
        // Загружаем настройки из UserDefaults
        if let savedMode = UserDefaults.standard.string(forKey: "PerformanceOptimizationMode"),
           let mode = OptimizationMode(rawValue: savedMode) {
            optimizationMode = mode
        }
        
        maxCacheSize = UserDefaults.standard.integer(forKey: "MaxCacheSize")
        if maxCacheSize == 0 {
            maxCacheSize = PerformanceConstants.maxCacheSize
        }
        
        enableTexturePooling = UserDefaults.standard.bool(forKey: "EnableTexturePooling")
        enableAsyncProcessing = UserDefaults.standard.bool(forKey: "EnableAsyncProcessing")
        enableAdaptivePerformance = UserDefaults.standard.bool(forKey: "EnableAdaptivePerformance")
        enableSystemMonitoring = UserDefaults.standard.bool(forKey: "EnableSystemMonitoring")
    }
    
    private func saveSettings() {
        // Сохраняем настройки в UserDefaults
        UserDefaults.standard.set(optimizationMode.rawValue, forKey: "PerformanceOptimizationMode")
        UserDefaults.standard.set(maxCacheSize, forKey: "MaxCacheSize")
        UserDefaults.standard.set(enableTexturePooling, forKey: "EnableTexturePooling")
        UserDefaults.standard.set(enableAsyncProcessing, forKey: "EnableAsyncProcessing")
        UserDefaults.standard.set(enableAdaptivePerformance, forKey: "EnableAdaptivePerformance")
        UserDefaults.standard.set(enableSystemMonitoring, forKey: "EnableSystemMonitoring")
    }
}

// MARK: - Расширения для удобства

extension PerformanceConstants {
    
    /// Проверяет, нужно ли применять оптимизацию для батареи
    static func shouldOptimizeForBattery() -> Bool {
        // Здесь можно добавить логику проверки уровня заряда батареи
        return false
    }
    
    /// Проверяет, нужно ли применять тепловое throttling
    static func shouldApplyThermalThrottling() -> Bool {
        // Здесь можно добавить логику проверки теплового состояния
        return false
    }
    
    /// Проверяет, есть ли давление на память
    static func hasMemoryPressure() -> Bool {
        // Здесь можно добавить логику проверки давления памяти
        return false
    }
    
    /// Получает рекомендуемый размер кэша на основе доступной памяти
    static func getRecommendedCacheSize() -> Int {
        // Здесь можно добавить логику расчета на основе доступной памяти
        return maxCacheSize
    }
}

// MARK: - ViewModel для настроек производительности

/// ViewModel для экрана настроек производительности
@MainActor
public class PerformanceSettingsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var settings: PerformanceSettings
    @Published var isApplyingSettings = false
    @Published var showResetConfirmation = false
    @Published var settingsChanged = false
    
    // Статистика системы
    @Published var systemInfo: SystemInfo = SystemInfo()
    @Published var currentStats: PerformanceStats = PerformanceStats(
        memoryUsageMB: 0.0,
        gpuUtilization: 0.0,
        frameRate: 0.0,
        thermalState: .nominal
    )
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var originalSettings: PerformanceSettings
    private let statsUpdateTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()
    
    // MARK: - Initialization
    
    init(settings: PerformanceSettings? = nil) {
        let initialSettings = settings ?? PerformanceSettings()
        self.settings = initialSettings
        self.originalSettings = initialSettings
        setupSubscriptions()
        updateSystemInfo()
    }
    
    // MARK: - Setup
    
    private func setupSubscriptions() {
        // Отслеживаем изменения настроек
        settings.objectWillChange
            .sink { [weak self] in
                self?.settingsChanged = true
            }
            .store(in: &cancellables)
        
        // Обновляем статистику периодически
        statsUpdateTimer
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updatePerformanceStats()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Применяет настройки производительности
    func applySettings() async {
        isApplyingSettings = true
        
        // Симулируем применение настроек
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 секунды
        
        settings.applySettings()
        originalSettings = settings
        settingsChanged = false
        isApplyingSettings = false
        
        print("✅ Performance settings applied successfully")
    }
    
    /// Сбрасывает настройки к значениям по умолчанию
    func resetToDefaults() {
        settings.resetToDefaults()
        settingsChanged = true
        showResetConfirmation = false
    }
    
    /// Отменяет изменения и возвращает к исходным настройкам
    func cancelChanges() {
        settings = originalSettings
        settingsChanged = false
    }
    
    /// Экспортирует настройки в файл
    func exportSettings() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(ExportableSettings(from: settings))
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            print("❌ Failed to export settings: \(error)")
            return ""
        }
    }
    
    /// Импортирует настройки из строки JSON
    func importSettings(from jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8) else { return false }
        
        do {
            let decoder = JSONDecoder()
            let exportableSettings = try decoder.decode(ExportableSettings.self, from: data)
            exportableSettings.applyTo(settings)
            settingsChanged = true
            return true
        } catch {
            print("❌ Failed to import settings: \(error)")
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func updateSystemInfo() {
        systemInfo = SystemInfo()
    }
    
    private func updatePerformanceStats() {
        // Здесь можно добавить обновление статистики производительности
        // Пока что используем заглушки
        let newStats = PerformanceStats(
            memoryUsageMB: Double.random(in: 100...500),
            gpuUtilization: Float.random(in: 0.2...0.8),
            frameRate: Float.random(in: 30...60),
            thermalState: ThermalState.allCases.randomElement() ?? .nominal
        )
        currentStats = newStats
    }
}

// MARK: - Supporting Types

/// Информация о системе
public struct SystemInfo {
    let deviceName: String
    let metalSupported: Bool
    let availableMemoryMB: Int
    let gpuName: String
    let maxThreadsPerGroup: Int
    
    init() {
        #if os(macOS)
        self.deviceName = Host.current().localizedName ?? "Unknown Mac"
        #elseif os(iOS)
        self.deviceName = UIDevice.current.name
        #else
        self.deviceName = "Unknown Device"
        #endif
        
        if let device = MTLCreateSystemDefaultDevice() {
            self.metalSupported = true
            self.gpuName = device.name
            self.maxThreadsPerGroup = device.maxThreadsPerThreadgroup.width
        } else {
            self.metalSupported = false
            self.gpuName = "Not Available"
            self.maxThreadsPerGroup = 0
        }
        
        // Примерная оценка доступной памяти
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        self.availableMemoryMB = Int(physicalMemory / (1024 * 1024))
    }
}

/// Статистика производительности
public struct PerformanceStats {
    let memoryUsageMB: Double
    let gpuUtilization: Float
    let frameRate: Float
    let thermalState: ThermalState
}

/// Состояние теплового режима
public enum ThermalState: String, CaseIterable {
    case nominal = "Nominal"
    case fair = "Fair"
    case serious = "Serious"
    case critical = "Critical"
    
    var color: Color {
        switch self {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .nominal: return "thermometer.low"
        case .fair: return "thermometer.medium"
        case .serious: return "thermometer.high"
        case .critical: return "exclamationmark.thermometer"
        }
    }
}

/// Экспортируемые настройки
public struct ExportableSettings: Codable {
    let optimizationMode: String
    let maxCacheSize: Int
    let enableTexturePooling: Bool
    let enableAsyncProcessing: Bool
    let enableAdaptivePerformance: Bool
    let enableSystemMonitoring: Bool
    
    @MainActor
    init(from settings: PerformanceSettings) {
        self.optimizationMode = settings.optimizationMode.rawValue
        self.maxCacheSize = settings.maxCacheSize
        self.enableTexturePooling = settings.enableTexturePooling
        self.enableAsyncProcessing = settings.enableAsyncProcessing
        self.enableAdaptivePerformance = settings.enableAdaptivePerformance
        self.enableSystemMonitoring = settings.enableSystemMonitoring
    }
    
    @MainActor
    func applyTo(_ settings: PerformanceSettings) {
        if let mode = PerformanceSettings.OptimizationMode(rawValue: optimizationMode) {
            settings.optimizationMode = mode
        }
        settings.maxCacheSize = maxCacheSize
        settings.enableTexturePooling = enableTexturePooling
        settings.enableAsyncProcessing = enableAsyncProcessing
        settings.enableAdaptivePerformance = enableAdaptivePerformance
        settings.enableSystemMonitoring = enableSystemMonitoring
    }
}
