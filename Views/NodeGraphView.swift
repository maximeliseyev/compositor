//
//  NodeGraphView.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 10.07.2025.
//


//
//  NodeGraphView.swift
//  Compositor
//
//  Enhanced Node-based Interface
//

import SwiftUI
import CoreImage

struct NodeGraphView: View {
    @StateObject private var nodeGraph = NodeGraph()
    @StateObject private var imageProcessor = ImageProcessor()
    @State private var dragOffset = CGSize.zero
    @State private var selectedNode: CompositorNode?
    @State private var isDraggingConnection = false
    @State private var connectionStart: CGPoint = .zero
    @State private var connectionEnd: CGPoint = .zero
    @State private var sourceNode: CompositorNode?
    @State private var inputImage: NSImage?
    @State private var processedImage: NSImage?
    
    var body: some View {
        HSplitView {
            // Левая панель с инструментами
            VStack(alignment: .leading, spacing: 15) {
                Text("Node Tools")
                    .font(.headline)
                    .padding(.bottom, 5)
                
                Button("Load Image") {
                    loadImage()
                }
                .buttonStyle(.borderedProminent)
                
                Divider()
                
                Text("Add Nodes")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ForEach(NodeType.allCases, id: \.self) { nodeType in
                    if nodeType != .imageInput { // Image Input создается автоматически
                        Button(nodeType.rawValue) {
                            addNode(type: nodeType)
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                Divider()
                
                if let selectedNode = selectedNode {
                    NodeParametersView(node: selectedNode, nodeGraph: nodeGraph) {
                        processGraph()
                    }
                }
                
                Spacer()
                
                if processedImage != nil {
                    Button("Export Image") {
                        exportImage()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 280)
            
            // Центральная область с графом нодов
            GeometryReader { geometry in
                ZStack {
                    // Фон с сеткой
                    GridBackground()
                    
                    // Соединения между нодами
                    ForEach(nodeGraph.connections) { connection in
                        if let fromNode = nodeGraph.nodes.first(where: { $0.id == connection.fromNode }),
                           let toNode = nodeGraph.nodes.first(where: { $0.id == connection.toNode }) {
                            NodeConnectionView(
                                from: fromNode.position,
                                to: toNode.position
                            )
                        }
                    }
                    
                    // Временное соединение при перетаскивании
                    if isDraggingConnection {
                        NodeConnectionView(
                            from: connectionStart,
                            to: connectionEnd,
                            isTemporary: true
                        )
                    }
                    
                    // Ноды
                    ForEach(nodeGraph.nodes) { node in
                        NodeView(
                            node: node,
                            isSelected: selectedNode?.id == node.id
                        )
                        .position(node.position)
                        .onTapGesture {
                            selectedNode = node
                        }
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if selectedNode?.id == node.id {
                                        nodeGraph.moveNode(node, to: value.location)
                                    }
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    if !isDraggingConnection {
                                        isDraggingConnection = true
                                        connectionStart = node.position
                                        sourceNode = node
                                    }
                                    connectionEnd = value.location
                                }
                                .onEnded { value in
                                    // Проверяем, попали ли мы на другой нод
                                    if let targetNode = nodeGraph.nodes.first(where: { otherNode in
                                        otherNode.id != node.id &&
                                        distance(from: value.location, to: otherNode.position) < 50
                                    }) {
                                        nodeGraph.connectNodes(from: node, to: targetNode)
                                        processGraph()
                                    }
                                    isDraggingConnection = false
                                    sourceNode = nil
                                }
                        )
                    }
                }
            }
            .clipped()
            .onTapGesture {
                selectedNode = nil
            }
            
            // Правая панель с результатом
            VStack {
                Text("Output")
                    .font(.headline)
                    .padding(.bottom, 10)
                
                if let image = processedImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.1))
                        .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Text("No output")
                                .foregroundColor(.secondary)
                        )
                        .cornerRadius(8)
                }
            }
            .padding()
            .frame(width: 300)
        }
        .navigationTitle("Node Graph Compositor")
        .onChange(of: nodeGraph.nodes) { _ in
            processGraph()
        }
        .onChange(of: nodeGraph.connections) { _ in
            processGraph()
        }
    }
    
    private func addNode(type: NodeType) {
        let center = CGPoint(x: 400, y: 300)
        nodeGraph.addNode(type: type, position: center)
    }
    
    private func loadImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK {
            if let url = panel.url,
               let image = NSImage(contentsOf: url) {
                inputImage = image
                
                // Создаем или обновляем input node
                if let inputNode = nodeGraph.nodes.first(where: { $0.type == .imageInput }) {
                    nodeGraph.setInputImage(for: inputNode, image: image)
                } else {
                    let inputNode = nodeGraph.addInputNode(image: image, position: CGPoint(x: 100, y: 300))
                    selectedNode = inputNode
                }
                
                processGraph()
            }
        }
    }
    
    private func processGraph() {
        guard let finalImage = nodeGraph.processGraph() else { return }
        processedImage = imageProcessor.ciImageToNSImage(finalImage)
    }
    
    private func exportImage() {
        guard let image = processedImage else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.nameFieldStringValue = "compositor_output"
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                if let tiffData = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData) {
                    let pngData = bitmap.representation(using: .png, properties: [:])
                    try? pngData?.write(to: url)
                }
            }
        }
    }
    
    private func distance(from: CGPoint, to: CGPoint) -> CGFloat {
        let dx = from.x - to.x
        let dy = from.y - to.y
        return sqrt(dx * dx + dy * dy)
    }
}

// Визуальное представление нода
struct NodeView: View {
    let node: CompositorNode
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // Заголовок нода
            Text(node.type.rawValue)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(nodeColor)
                .cornerRadius(4)
            
            // Тело нода
            VStack(spacing: 4) {
                // Входной порт
                if node.type != .imageInput {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .offset(x: -50)
                }
                
                // Основная область
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 100, height: 60)
                    .overlay(
                        VStack(spacing: 2) {
                            // Показываем основные параметры
                            ForEach(Array(node.parameters.prefix(2)), id: \.key) { key, value in
                                HStack {
                                    Text(key.prefix(4))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(String(format: "%.1f", value))
                                        .font(.caption2)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                    )
                
                // Выходной порт
                if node.type != .output {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .offset(x: 50)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
    
    private var nodeColor: Color {
        switch node.type {
        case .imageInput:
            return .blue
        case .colorCorrection:
            return .purple
        case .blur:
            return .orange
        case .sharpen:
            return .red
        case .output:
            return .green
        }
    }
}

// Визуальное представление соединения
struct NodeConnectionView: View {
    let from: CGPoint
    let to: CGPoint
    let isTemporary: Bool
    
    init(from: CGPoint, to: CGPoint, isTemporary: Bool = false) {
        self.from = from
        self.to = to
        self.isTemporary = isTemporary
    }
    
    var body: some View {
        Path { path in
            path.move(to: from)
            
            let controlPoint1 = CGPoint(x: from.x + 100, y: from.y)
            let controlPoint2 = CGPoint(x: to.x - 100, y: to.y)
            
            path.addCurve(to: to, control1: controlPoint1, control2: controlPoint2)
        }
        .stroke(
            isTemporary ? Color.gray.opacity(0.5) : Color.blue,
            lineWidth: 2
        )
    }
}

// Панель параметров нода
struct NodeParametersView: View {
    let node: CompositorNode
    let nodeGraph: NodeGraph
    let onParameterChanged: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Parameters")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            ForEach(Array(node.parameters.keys.sorted()), id: \.self) { key in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(key.capitalized): \(node.parameters[key] ?? 0, specifier: "%.2f")")
                        .font(.caption)
                    
                    Slider(
                        value: Binding(
                            get: { node.parameters[key] ?? 0 },
                            set: { newValue in
                                nodeGraph.updateNodeParameter(node, key: key, value: newValue)
                                onParameterChanged()
                            }
                        ),
                        in: parameterRange(for: key)
                    )
                }
            }
            
            Button("Remove Node") {
                nodeGraph.removeNode(node)
                onParameterChanged()
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func parameterRange(for key: String) -> ClosedRange<Double> {
        switch key {
        case "brightness":
            return -1...1
        case "contrast", "saturation":
            return 0...2
        case "radius":
            return 0...20
        case "intensity":
            return 0...2
        case "exposure":
            return -3...3
        default:
            return 0...1
        }
    }
}

// Фон с сеткой
struct GridBackground: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 20
            
            context.stroke(
                Path { path in
                    for x in stride(from: 0, through: size.width, by: spacing) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    for y in stride(from: 0, through: size.height, by: spacing) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                },
                with: .color(.gray.opacity(0.1)),
                lineWidth: 0.5
            )
        }
    }
}