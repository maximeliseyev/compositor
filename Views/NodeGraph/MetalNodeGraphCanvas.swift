//
//  MetalNodeGraphCanvas.swift
//  Compositor
//
//  Renders grid, connections, and selection in one Metal pass
//

import SwiftUI
import Metal
import MetalKit

struct MetalNodeGraphCanvas: NSViewRepresentable {
    // Input
    let size: CGSize
    let gridSpacing: CGFloat
    let connections: [(from: CGPoint, to: CGPoint)]
    let previewConnection: (from: CGPoint, to: CGPoint)?
    let selectionRect: CGRect?

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.colorPixelFormat = .bgra8Unorm
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        view.preferredFramesPerSecond = 60
        view.delegate = context.coordinator
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.update(size: size,
                                   gridSpacing: gridSpacing,
                                   connections: connections,
                                   previewConnection: previewConnection,
                                   selectionRect: selectionRect)
        nsView.setNeedsDisplay(nsView.bounds)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        private var device: MTLDevice?
        private var commandQueue: MTLCommandQueue?
        private var pipelineState: MTLRenderPipelineState?

        // Cached inputs
        private var size: CGSize = .zero
        private var gridSpacing: CGFloat = 40
        private var connections: [(CGPoint, CGPoint)] = []
        private var previewConnection: (CGPoint, CGPoint)? = nil
        private var selectionRect: CGRect? = nil

        func update(size: CGSize,
                    gridSpacing: CGFloat,
                    connections: [(CGPoint, CGPoint)],
                    previewConnection: (CGPoint, CGPoint)?,
                    selectionRect: CGRect?) {
            self.size = size
            self.gridSpacing = gridSpacing
            self.connections = connections
            self.previewConnection = previewConnection
            self.selectionRect = selectionRect
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // no-op
        }

        func draw(in view: MTKView) {
            ensureMetal(view: view)
            guard let device = device,
                  let commandQueue = commandQueue,
                  let drawable = view.currentDrawable,
                  let renderPass = view.currentRenderPassDescriptor
            else { return }

            // Dark gray background to reduce eye strain
            renderPass.colorAttachments[0].clearColor = MTLClearColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)
            renderPass.colorAttachments[0].loadAction = .clear
            renderPass.colorAttachments[0].storeAction = .store

            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass)
            else { return }

            // Pipeline
            if pipelineState == nil {
                pipelineState = createPipelineState(device: device, pixelFormat: view.colorPixelFormat)
            }
            guard let pipelineState = pipelineState else {
                encoder.endEncoding()
                commandBuffer.present(drawable)
                commandBuffer.commit()
                return
            }
            encoder.setRenderPipelineState(pipelineState)

            // Draw grid (light gray lines over dark background)
            if let gridBuffer = makeGridVertexBuffer(device: device, size: size, spacing: gridSpacing) {
                encoder.setVertexBuffer(gridBuffer, offset: 0, index: 0)
                let lineCount = gridBuffer.length / MemoryLayout<Float>.size / 2 // 2 floats per vertex
                setColor(encoder: encoder, color: SIMD4<Float>(0.25, 0.25, 0.25, 1.0))
                encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: lineCount)
            }

            // Draw connections
            if let connectionsBuffer = makeConnectionsVertexBuffer(device: device, size: size, connections: connections) {
                encoder.setVertexBuffer(connectionsBuffer, offset: 0, index: 0)
                let vertexCount = connectionsBuffer.length / MemoryLayout<Float>.size / 2
                setColor(encoder: encoder, color: SIMD4<Float>(1, 1, 1, 1))
                encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: vertexCount)
            }

            // Draw preview connection
            if let preview = previewConnection,
               let previewBuffer = makeConnectionsVertexBuffer(device: device, size: size, connections: [preview]) {
                encoder.setVertexBuffer(previewBuffer, offset: 0, index: 0)
                let vertexCount = previewBuffer.length / MemoryLayout<Float>.size / 2
                setColor(encoder: encoder, color: SIMD4<Float>(1, 1, 0, 1))
                encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: vertexCount)
            }

            // Draw selection rectangle (filled with alpha)
            if let rect = selectionRect,
               let rectBuffer = makeSelectionRectBuffer(device: device, size: size, rect: rect) {
                encoder.setVertexBuffer(rectBuffer, offset: 0, index: 0)
                setColor(encoder: encoder, color: SIMD4<Float>(0.0, 0.5, 1.0, 0.15))
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            }

            encoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }

        private func ensureMetal(view: MTKView) {
            if device == nil {
                device = view.device
            }
            if commandQueue == nil, let device = device {
                commandQueue = device.makeCommandQueue()
            }
        }

        private func createPipelineState(device: MTLDevice, pixelFormat: MTLPixelFormat) -> MTLRenderPipelineState? {
            guard let library = device.makeDefaultLibrary() else { return nil }
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "ui_vertex")
            descriptor.fragmentFunction = library.makeFunction(name: "ui_fragment")
            descriptor.colorAttachments[0].pixelFormat = pixelFormat
            // Enable standard alpha blending so translucent overlays (selection) look correct
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].rgbBlendOperation = .add
            descriptor.colorAttachments[0].alphaBlendOperation = .add
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            return try? device.makeRenderPipelineState(descriptor: descriptor)
        }

        private func setColor(encoder: MTLRenderCommandEncoder, color: SIMD4<Float>) {
            var color = color
            encoder.setFragmentBytes(&color, length: MemoryLayout<SIMD4<Float>>.size, index: 0)
        }

        private func makeGridVertexBuffer(device: MTLDevice, size: CGSize, spacing: CGFloat) -> MTLBuffer? {
            var vertices: [Float] = []
            // Vertical lines
            var x: CGFloat = 0
            while x <= size.width {
                let p0 = toNDC(CGPoint(x: x, y: 0), size: size)
                let p1 = toNDC(CGPoint(x: x, y: size.height), size: size)
                vertices.append(contentsOf: [Float(p0.x), Float(p0.y), Float(p1.x), Float(p1.y)])
                x += spacing
            }
            // Horizontal lines
            var y: CGFloat = 0
            while y <= size.height {
                let p0 = toNDC(CGPoint(x: 0, y: y), size: size)
                let p1 = toNDC(CGPoint(x: size.width, y: y), size: size)
                vertices.append(contentsOf: [Float(p0.x), Float(p0.y), Float(p1.x), Float(p1.y)])
                y += spacing
            }
            guard !vertices.isEmpty else { return nil }
            return device.makeBuffer(bytes: vertices,
                                     length: vertices.count * MemoryLayout<Float>.size,
                                     options: .storageModeShared)
        }

        private func makeConnectionsVertexBuffer(device: MTLDevice, size: CGSize, connections: [(CGPoint, CGPoint)]) -> MTLBuffer? {
            var vertices: [Float] = []
            for (from, to) in connections {
                let p0 = toNDC(from, size: size)
                let p1 = toNDC(to, size: size)
                vertices.append(contentsOf: [Float(p0.x), Float(p0.y), Float(p1.x), Float(p1.y)])
            }
            guard !vertices.isEmpty else { return nil }
            return device.makeBuffer(bytes: vertices,
                                     length: vertices.count * MemoryLayout<Float>.size,
                                     options: .storageModeShared)
        }

        private func makeSelectionRectBuffer(device: MTLDevice, size: CGSize, rect: CGRect) -> MTLBuffer? {
            // Build triangle strip: bottom-left, bottom-right, top-left, top-right in NDC
            let bl = toNDC(CGPoint(x: rect.minX, y: rect.maxY), size: size)
            let br = toNDC(CGPoint(x: rect.maxX, y: rect.maxY), size: size)
            let tl = toNDC(CGPoint(x: rect.minX, y: rect.minY), size: size)
            let tr = toNDC(CGPoint(x: rect.maxX, y: rect.minY), size: size)
            let vertices: [Float] = [Float(bl.x), Float(bl.y), Float(br.x), Float(br.y), Float(tl.x), Float(tl.y), Float(tr.x), Float(tr.y)]
            return device.makeBuffer(bytes: vertices,
                                     length: vertices.count * MemoryLayout<Float>.size,
                                     options: .storageModeShared)
        }

        private func toNDC(_ p: CGPoint, size: CGSize) -> CGPoint {
            // Convert UI coords (origin top-left) to NDC (origin center, y up)
            let x = (p.x / max(size.width, 1)) * 2.0 - 1.0
            let yTopLeft = (p.y / max(size.height, 1))
            let y = 1.0 - yTopLeft * 2.0
            return CGPoint(x: x, y: y)
        }
    }
}


