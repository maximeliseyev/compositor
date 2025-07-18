//
//  MetalRenderer.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 18.07.2025.
//

import Foundation
import SwiftUI
import Metal
import MetalKit

/// Базовый протокол для Metal рендерера
protocol MetalRendererProtocol {
    func renderConnections(connections: [NodeConnection], nodes: [BaseNode], in view: MTKView)
    func renderSelectionRectangle(rect: CGRect, in view: MTKView)
    func renderPreviewConnection(from: CGPoint, to: CGPoint, in view: MTKView)
    func renderGrid(size: CGSize, in view: MTKView)
}

/// Конфигурация для Metal рендерера
struct MetalRendererConfig {
    let devicePreference: MTLFeatureSet
    let enableAntialiasing: Bool
    let maxFrameRate: Int
    let enableAsyncRendering: Bool
    
    static let `default` = MetalRendererConfig(
        devicePreference: .macOS_GPUFamily2_v1,
        enableAntialiasing: true,
        maxFrameRate: 60,
        enableAsyncRendering: true
    )
}

/// Базовый Metal рендерер для NodeGraph
/// Пока не подключен к проекту, готов для будущего использования
class MetalRenderer: NSObject, MetalRendererProtocol {
    
    // MARK: - Properties
    
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var config: MetalRendererConfig
    
    // Buffers для геометрии
    private var vertexBuffer: MTLBuffer?
    private var indexBuffer: MTLBuffer?
    
    // Кэш для оптимизации
    private var connectionCache: [UUID: MetalConnectionData] = [:]
    private var gridCache: MetalGridData?
    
    // MARK: - Initialization
    
    init(config: MetalRendererConfig = .default) {
        self.config = config
        super.init()
        setupMetal()
    }
    
    // MARK: - Metal Setup
    
    private func setupMetal() {
        // Инициализация Metal устройства
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }
        
        self.device = device
        self.commandQueue = device.makeCommandQueue()
        
        setupPipelineState()
        setupBuffers()
    }
    
    private func setupPipelineState() {
        guard let device = device else { return }
        
        // Создание библиотеки шейдеров
        let library = device.makeDefaultLibrary()
        
        // Vertex и fragment функции (пока placeholder)
        let vertexFunction = library?.makeFunction(name: "vertex_main")
        let fragmentFunction = library?.makeFunction(name: "fragment_main")
        
        // Настройка pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // Настройка антиалиасинга
        if config.enableAntialiasing {
            pipelineDescriptor.sampleCount = 4
        }
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Error creating pipeline state: \(error)")
        }
    }
    
    private func setupBuffers() {
        guard let device = device else { return }
        
        // Создание буферов для вершин и индексов
        let vertexData: [Float] = [
            -1.0, -1.0, 0.0, 1.0,  // bottom-left
             1.0, -1.0, 0.0, 1.0,  // bottom-right
             1.0,  1.0, 0.0, 1.0,  // top-right
            -1.0,  1.0, 0.0, 1.0   // top-left
        ]
        
        let indexData: [UInt16] = [0, 1, 2, 2, 3, 0]
        
        vertexBuffer = device.makeBuffer(bytes: vertexData, length: vertexData.count * MemoryLayout<Float>.size, options: [])
        indexBuffer = device.makeBuffer(bytes: indexData, length: indexData.count * MemoryLayout<UInt16>.size, options: [])
    }
    
    // MARK: - Rendering Methods
    
    func renderConnections(connections: [NodeConnection], nodes: [BaseNode], in view: MTKView) {
        guard let device = device,
              let commandQueue = commandQueue,
              let pipelineState = pipelineState else { return }
        
        // Создание command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        // Получение текущего drawable
        guard let drawable = view.currentDrawable else { return }
        
        // Создание render pass descriptor
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        
        // Создание render encoder
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        
        // Рендеринг связей
        for connection in connections {
            renderConnection(connection, nodes: nodes, encoder: renderEncoder)
        }
        
        renderEncoder.endEncoding()
        
        // Презентация результата
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    private func renderConnection(_ connection: NodeConnection, nodes: [BaseNode], encoder: MTLRenderCommandEncoder) {
        // Найти узлы соединения
        guard let fromNode = nodes.first(where: { $0.id == connection.fromNode }),
              let toNode = nodes.first(where: { $0.id == connection.toNode }) else { return }
        
        // Получить позиции портов (пока используем позиции узлов)
        let fromPoint = fromNode.position
        let toPoint = toNode.position
        
        // Кэширование геометрии соединения
        if connectionCache[connection.id] == nil {
            connectionCache[connection.id] = MetalConnectionData(
                from: fromPoint,
                to: toPoint,
                lineWidth: 1.0,
                color: [1.0, 1.0, 1.0, 1.0] // белый цвет
            )
        }
        
        // Установка буферов и рендеринг
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }
    
    func renderSelectionRectangle(rect: CGRect, in view: MTKView) {
        // TODO: Реализовать рендеринг прямоугольника выделения
    }
    
    func renderPreviewConnection(from: CGPoint, to: CGPoint, in view: MTKView) {
        // TODO: Реализовать рендеринг предварительного соединения
    }
    
    func renderGrid(size: CGSize, in view: MTKView) {
        // TODO: Реализовать рендеринг сетки
    }
    
    // MARK: - Cache Management
    
    func clearConnectionCache() {
        connectionCache.removeAll()
    }
    
    func clearConnectionCache(for nodeId: UUID) {
        connectionCache = connectionCache.filter { _, data in
            // Удаляем кэш для соединений, связанных с узлом
            return true // TODO: Реализовать логику фильтрации
        }
    }
    
    // MARK: - Performance Optimization
    
    func setFrameRate(_ fps: Int) {
        // TODO: Реализовать ограничение частоты кадров
    }
    
    func enableAsyncRendering(_ enabled: Bool) {
        // TODO: Реализовать асинхронный рендеринг
    }
}

// MARK: - Data Structures

/// Данные для кэширования соединений в Metal
struct MetalConnectionData {
    let from: CGPoint
    let to: CGPoint
    let lineWidth: Float
    let color: [Float] // RGBA
}

/// Данные для кэширования сетки в Metal
struct MetalGridData {
    let size: CGSize
    let gridSpacing: Float
    let lineWidth: Float
    let color: [Float] // RGBA
}

// MARK: - SwiftUI Integration (для будущего использования)

/// SwiftUI представление для Metal рендерера
struct MetalNodeGraphView: NSViewRepresentable {
    let connections: [NodeConnection]
    let nodes: [BaseNode]
    let renderer: MetalRenderer
    
    func makeNSView(context: Context) -> MTKView {
        let metalView = MTKView()
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.delegate = context.coordinator
        metalView.framebufferOnly = false
        metalView.preferredFramesPerSecond = 60
        return metalView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        // Обновление данных для рендеринга
        context.coordinator.updateData(connections: connections, nodes: nodes)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(renderer: renderer)
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        private let renderer: MetalRenderer
        private var connections: [NodeConnection] = []
        private var nodes: [BaseNode] = []
        
        init(renderer: MetalRenderer) {
            self.renderer = renderer
        }
        
        func updateData(connections: [NodeConnection], nodes: [BaseNode]) {
            self.connections = connections
            self.nodes = nodes
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Обновление размеров viewport
        }
        
        func draw(in view: MTKView) {
            renderer.renderConnections(connections: connections, nodes: nodes, in: view)
        }
    }
}

/// Шейдеры для Metal (пока placeholder)
extension MetalRenderer {
    static let vertexShader = """
    #include <metal_stdlib>
    using namespace metal;
    
    vertex float4 vertex_main(uint vertexID [[vertex_id]]) {
        return float4(0.0, 0.0, 0.0, 1.0);
    }
    """
    
    static let fragmentShader = """
    #include <metal_stdlib>
    using namespace metal;
    
    fragment float4 fragment_main() {
        return float4(1.0, 1.0, 1.0, 1.0);
    }
    """
} 