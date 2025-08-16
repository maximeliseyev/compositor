//
//  MetalNodeGraphCanvas.swift
//  Compositor
//
//  Renders grid, connections, and selection in one Metal pass
//

import SwiftUI
import Metal
import MetalKit
// NodeGraphRenderStyle is colocated in Views/NodeGraph/Rendering
// No explicit module import needed inside app target

struct NodeRenderItem {
    let position: CGPoint
    let size: CGSize
    let cornerRadius: CGFloat
    let isSelected: Bool
}

struct MetalNodeGraphCanvas: NSViewRepresentable {
    // Input
    let size: CGSize
    let gridSpacing: CGFloat
    let connections: [(from: CGPoint, to: CGPoint)]
    let previewConnection: (from: CGPoint, to: CGPoint)?
    let selectionRect: CGRect?
    let nodes: [NodeRenderItem]

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
                                   selectionRect: selectionRect,
                                   nodes: nodes)
        nsView.setNeedsDisplay(nsView.bounds)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        private var device: MTLDevice?
        private var commandQueue: MTLCommandQueue?
        private var linePipelineState: MTLRenderPipelineState?
        private var nodePipelineState: MTLRenderPipelineState?

        // Cached inputs
        private var size: CGSize = .zero
        private var gridSpacing: CGFloat = 40
        private var connections: [(CGPoint, CGPoint)] = []
        private var previewConnection: (CGPoint, CGPoint)? = nil
        private var selectionRect: CGRect? = nil
        private var nodesToDraw: [NodeRenderItem] = []

        func update(size: CGSize,
                    gridSpacing: CGFloat,
                    connections: [(CGPoint, CGPoint)],
                    previewConnection: (CGPoint, CGPoint)?,
                    selectionRect: CGRect?,
                    nodes: [NodeRenderItem]) {
            self.size = size
            self.gridSpacing = gridSpacing
            self.connections = connections
            self.previewConnection = previewConnection
            self.selectionRect = selectionRect
            self.nodesToDraw = nodes
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

            // Apply canvas background color
            renderPass.colorAttachments[0].clearColor = NodeGraphRenderStyle.backgroundClearColor
            renderPass.colorAttachments[0].loadAction = .clear
            renderPass.colorAttachments[0].storeAction = .store

            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass)
            else { return }

            // Pipelines (cached)
            if linePipelineState == nil || nodePipelineState == nil {
                buildPipelines(device: device, pixelFormat: view.colorPixelFormat)
            }
            guard let linePipelineState = linePipelineState, let nodePipelineState = nodePipelineState else {
                encoder.endEncoding()
                commandBuffer.present(drawable)
                commandBuffer.commit()
                return
            }
            encoder.setRenderPipelineState(linePipelineState)

            // Draw grid (using predefined light gray color)
            if let gridBuffer = makeGridVertexBuffer(device: device, size: size, spacing: gridSpacing) {
                encoder.setVertexBuffer(gridBuffer, offset: 0, index: 0)
                let lineCount = gridBuffer.length / MemoryLayout<Float>.size / 2 // 2 floats per vertex
                setColor(encoder: encoder, color: NodeGraphRenderStyle.gridLineColor)
                encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: lineCount)
            }

            // Draw connections (white color)
            if let connectionsBuffer = makeConnectionsVertexBuffer(device: device, size: size, connections: connections) {
                encoder.setVertexBuffer(connectionsBuffer, offset: 0, index: 0)
                let vertexCount = connectionsBuffer.length / MemoryLayout<Float>.size / 2
                setColor(encoder: encoder, color: NodeGraphRenderStyle.connectionLineColor)
                encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: vertexCount)
            }

            // Draw preview connection (yellow color)
            if let preview = previewConnection,
               let previewBuffer = makeConnectionsVertexBuffer(device: device, size: size, connections: [preview]) {
                encoder.setVertexBuffer(previewBuffer, offset: 0, index: 0)
                let vertexCount = previewBuffer.length / MemoryLayout<Float>.size / 2
                setColor(encoder: encoder, color: NodeGraphRenderStyle.previewConnectionLineColor)
                encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: vertexCount)
            }

            // Draw selection rectangle (semi-transparent fill)
            if let rect = selectionRect,
               let rectBuffer = makeSelectionRectBuffer(device: device, size: size, rect: rect) {
                encoder.setVertexBuffer(rectBuffer, offset: 0, index: 0)
                setColor(encoder: encoder, color: NodeGraphRenderStyle.selectionFillColor)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            }

            // Draw nodes (rounded rectangles and selection outline)
            drawNodes(nodesToDraw, with: encoder, device: device, nodePipeline: nodePipelineState)

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

        private func buildPipelines(device: MTLDevice, pixelFormat: MTLPixelFormat) {
            guard let library = device.makeDefaultLibrary() else { return }
            // Line/grid pipeline
            do {
                let desc = MTLRenderPipelineDescriptor()
                desc.label = "NodeGraph.LinePipeline"
                let vtx = library.makeFunction(name: "ui_vertex")
                let frag = library.makeFunction(name: "ui_fragment")
                if vtx == nil { print("[Metal] Missing function ui_vertex in default library") }
                if frag == nil { print("[Metal] Missing function ui_fragment in default library") }
                if vtx == nil || frag == nil {
                    self.linePipelineState = nil
                    throw NSError(domain: "MetalNodeGraphCanvas", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing UI line shader functions"])
                }
                desc.vertexFunction = vtx
                desc.fragmentFunction = frag
                desc.colorAttachments[0].pixelFormat = pixelFormat
                desc.colorAttachments[0].isBlendingEnabled = true
                desc.colorAttachments[0].rgbBlendOperation = .add
                desc.colorAttachments[0].alphaBlendOperation = .add
                desc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
                desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
                desc.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
                desc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
                self.linePipelineState = try device.makeRenderPipelineState(descriptor: desc)
            } catch {
                print("[Metal] Failed to build line pipeline: \(error.localizedDescription)")
                self.linePipelineState = nil
            }

            // Node pipeline
            do {
                let desc = MTLRenderPipelineDescriptor()
                desc.label = "NodeGraph.NodePipeline"
                let vtx = library.makeFunction(name: "ui_node_vertex")
                let frag = library.makeFunction(name: "ui_rounded_rect_fragment")
                if vtx == nil { print("[Metal] Missing function ui_node_vertex in default library") }
                if frag == nil { print("[Metal] Missing function ui_rounded_rect_fragment in default library") }
                if vtx == nil || frag == nil {
                    self.nodePipelineState = nil
                    throw NSError(domain: "MetalNodeGraphCanvas", code: -2, userInfo: [NSLocalizedDescriptionKey: "Missing UI node shader functions"])
                }
                desc.vertexFunction = vtx
                desc.fragmentFunction = frag
                desc.colorAttachments[0].pixelFormat = pixelFormat
                desc.colorAttachments[0].isBlendingEnabled = true
                desc.colorAttachments[0].rgbBlendOperation = .add
                desc.colorAttachments[0].alphaBlendOperation = .add
                desc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
                desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
                desc.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
                desc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
                self.nodePipelineState = try device.makeRenderPipelineState(descriptor: desc)
            } catch {
                print("[Metal] Failed to build node pipeline: \(error.localizedDescription)")
                self.nodePipelineState = nil
            }
        }

        private func setColor(encoder: MTLRenderCommandEncoder, color: SIMD4<Float>) {
            var color = color
            encoder.setFragmentBytes(&color, length: MemoryLayout<SIMD4<Float>>.size, index: 0)
        }

        private func drawNodes(_ nodes: [NodeRenderItem], with encoder: MTLRenderCommandEncoder, device: MTLDevice, nodePipeline: MTLRenderPipelineState) {
            encoder.pushDebugGroup("Nodes")
            encoder.setRenderPipelineState(nodePipeline)

            for node in nodes {
                // Build base rect
                let rect = CGRect(x: node.position.x - node.size.width / 2,
                                  y: node.position.y - node.size.height / 2,
                                  width: node.size.width,
                                  height: node.size.height)

                // Draw selection outline first (behind body)
                if node.isSelected {
                    // Compute outline rect by expanding the body by a fixed thickness
                    let outlineThickness: CGFloat = NodeGraphRenderStyle.selectionOutlineThickness
                    let outlineInset: CGFloat = -outlineThickness
                    let outlineRect = rect.insetBy(dx: outlineInset, dy: outlineInset)
                    let oVerts = quadVertices(for: outlineRect, in: size)
                    let ovb = device.makeBuffer(bytes: oVerts, length: oVerts.count * MemoryLayout<Float>.size, options: .storageModeShared)
                    encoder.setVertexBuffer(ovb, offset: 0, index: 0)
                    var outlineColor = NodeGraphRenderStyle.selectionOutlineColor
                    // Convert corner radius in points to normalized UV-space radius expected by the fragment shader.
                    // We add the outline thickness so the outer shape follows the same curvature as the inner body.
                    var oradius: Float = Float((node.cornerRadius + outlineThickness) / max(outlineRect.width, outlineRect.height))
                    encoder.setFragmentBytes(&outlineColor, length: MemoryLayout<SIMD4<Float>>.size, index: 0)
                    encoder.setFragmentBytes(&oradius, length: MemoryLayout<Float>.size, index: 1)
                    encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
                }

                // Draw body on top
                let verts = quadVertices(for: rect, in: size)
                let vb = device.makeBuffer(bytes: verts, length: verts.count * MemoryLayout<Float>.size, options: .storageModeShared)
                encoder.setVertexBuffer(vb, offset: 0, index: 0)
                // Select appropriate body color depending on focus/selection state
                var bodyColor = node.isSelected ? NodeGraphRenderStyle.nodeBodySelectedColor : NodeGraphRenderStyle.nodeBodyColor
                var radius: Float = Float(node.cornerRadius / max(node.size.width, node.size.height))
                encoder.setFragmentBytes(&bodyColor, length: MemoryLayout<SIMD4<Float>>.size, index: 0)
                encoder.setFragmentBytes(&radius, length: MemoryLayout<Float>.size, index: 1)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            }

            encoder.popDebugGroup()
        }

        private func quadVertices(for rect: CGRect, in canvasSize: CGSize) -> [Float] {
            // Interleaved: position.xy (NDC), uv.xy (0..1)
            let bl = toNDC(CGPoint(x: rect.minX, y: rect.maxY), size: canvasSize)
            let br = toNDC(CGPoint(x: rect.maxX, y: rect.maxY), size: canvasSize)
            let tl = toNDC(CGPoint(x: rect.minX, y: rect.minY), size: canvasSize)
            let tr = toNDC(CGPoint(x: rect.maxX, y: rect.minY), size: canvasSize)
            return [
                Float(bl.x), Float(bl.y), 0.0, 0.0,
                Float(br.x), Float(br.y), 1.0, 0.0,
                Float(tl.x), Float(tl.y), 0.0, 1.0,
                Float(tr.x), Float(tr.y), 1.0, 1.0,
            ]
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


