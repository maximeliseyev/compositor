import Foundation
import Metal
import SwiftUI

// MARK: - Dependency Injection Protocol

protocol DIContainer {
    func resolve<T>(_ type: T.Type) -> T
    func register<T>(_ type: T.Type, factory: @escaping () -> T)
    func registerSingleton<T>(_ type: T.Type, factory: @escaping () -> T)
}

// MARK: - Compositor DI Container

class CompositorDIContainer: DIContainer {
    
    // MARK: - Private Properties
    
    private var factories: [String: () -> Any] = [:]
    private var singletons: [String: Any] = [:]
    private let lock = NSLock()
    
    // MARK: - Singleton
    
    static let shared = CompositorDIContainer()
    
    private init() {
        configureDefaultDependencies()
    }
    
    // MARK: - Registration Methods
    
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = String(describing: type)
        factories[key] = factory
    }
    
    func registerSingleton<T>(_ type: T.Type, factory: @escaping () -> T) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = String(describing: type)
        factories[key] = { [weak self] in
            if let existing = self?.singletons[key] as? T {
                return existing
            }
            let instance = factory()
            self?.singletons[key] = instance
            return instance
        }
    }
    
    // MARK: - Resolution Method
    
    func resolve<T>(_ type: T.Type) -> T {
        lock.lock()
        defer { lock.unlock() }
        
        let key = String(describing: type)
        guard let factory = factories[key] as? () -> T else {
            fatalError("❌ Type \(type) not registered in DI Container. Available types: \(factories.keys.joined(separator: ", "))")
        }
        return factory()
    }
    
    // MARK: - Default Configuration
    
    private func configureDefaultDependencies() {
        // Metal Infrastructure
        registerSingleton(MTLDevice.self) {
            guard let device = MTLCreateSystemDefaultDevice() else {
                fatalError("Metal not supported on this device")
            }
            print("🔧 DI: Created MTLDevice - \(device.name)")
            return device
        }
        
        registerSingleton(MTLCommandQueue.self) {
            let device = self.resolve(MTLDevice.self)
            guard let queue = device.makeCommandQueue() else {
                fatalError("Could not create Metal command queue")
            }
            print("🔧 DI: Created MTLCommandQueue")
            return queue
        }
        
        // Другие зависимости будут добавлены по мере необходимости
        print("🔧 DI: Basic Metal dependencies configured")
    }
}

// MARK: - SwiftUI Environment Integration

struct DIContainerKey: EnvironmentKey {
    static let defaultValue: DIContainer = CompositorDIContainer.shared
}

extension EnvironmentValues {
    var diContainer: DIContainer {
        get { self[DIContainerKey.self] }
        set { self[DIContainerKey.self] = newValue }
    }
}

extension View {
    func withDIContainer(_ container: DIContainer = CompositorDIContainer.shared) -> some View {
        self.environment(\.diContainer, container)
    }
}

// MARK: - Property Wrapper for DI

@propertyWrapper
struct Injected<T> {
    private let type: T.Type
    private let container: DIContainer
    
    init(_ type: T.Type, container: DIContainer = CompositorDIContainer.shared) {
        self.type = type
        self.container = container
    }
    
    var wrappedValue: T {
        return container.resolve(type)
    }
}

// MARK: - Usage Examples and Documentation

/*
 Usage Examples:
 
 1. In ViewModels:
 ```swift
 class NodeGraphViewModel: ObservableObject {
     @Injected(MetalRenderer.self) private var renderer
     @Injected(NodeGraphProcessor.self) private var processor
 }
 ```
 
 2. In Views:
 ```swift
 struct NodeGraphView: View {
     @Environment(\.diContainer) var container
     
     var body: some View {
         let viewModel = container.resolve(NodeGraphViewModel.self)
         // ...
     }
 }
 ```
 
 3. Custom Registration:
 ```swift
 container.register(CustomService.self) {
     CustomService(dependency: container.resolve(Dependency.self))
 }
 ```
 
 4. Singleton Registration:
 ```swift
 container.registerSingleton(ExpensiveService.self) {
     ExpensiveService()
 }
 ```
 */

// MARK: - Testing Support

#if DEBUG
extension CompositorDIContainer {
    func registerMock<T>(_ type: T.Type, mock: T) {
        register(type) { mock }
    }
    
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        
        factories.removeAll()
        singletons.removeAll()
        configureDefaultDependencies()
    }
}
#endif
