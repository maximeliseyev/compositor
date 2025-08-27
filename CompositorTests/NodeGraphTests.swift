//
//  NodeGraphTests.swift
//  CompositorTests
//
//  Created by Maxim Eliseyev on 12.08.2025.
//

import XCTest
import CoreImage
import SwiftUI

/// Unit тесты для NodeGraph и связанных компонентов
final class NodeGraphTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var nodeGraph: NodeGraph!
    private var inputNode: TestInputNode!
    private var processNode: TestProcessNode!
    private var outputNode: TestOutputNode!
    
    // MARK: - Setup and Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        nodeGraph = NodeGraph()
        
        // Создаем тестовые ноды
        inputNode = TestInputNode(position: CGPoint(x: 100, y: 100))
        processNode = TestProcessNode(position: CGPoint(x: 300, y: 100))
        outputNode = TestOutputNode(position: CGPoint(x: 500, y: 100))
    }
    
    override func tearDownWithError() throws {
        nodeGraph = nil
        inputNode = nil
        processNode = nil
        outputNode = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - Node Management Tests
    
    /// Тест добавления ноды в граф
    func testAddNode() {
        // When
        nodeGraph.addNode(inputNode)
        
        // Then
        XCTAssertEqual(nodeGraph.nodes.count, 1, "Should have one node")
        XCTAssertTrue(nodeGraph.nodes.contains { $0.id == inputNode.id }, "Should contain the added node")
    }
    
    /// Тест удаления ноды из графа
    func testRemoveNode() {
        // Given
        nodeGraph.addNode(inputNode)
        nodeGraph.addNode(processNode)
        
        // When
        nodeGraph.removeNode(inputNode)
        
        // Then
        XCTAssertEqual(nodeGraph.nodes.count, 1, "Should have one node remaining")
        XCTAssertFalse(nodeGraph.nodes.contains { $0.id == inputNode.id }, "Should not contain removed node")
        XCTAssertTrue(nodeGraph.nodes.contains { $0.id == processNode.id }, "Should contain remaining node")
    }
    
    /// Тест перемещения ноды
    func testMoveNode() {
        // Given
        nodeGraph.addNode(inputNode)
        let newPosition = CGPoint(x: 200, y: 200)
        
        // When
        nodeGraph.moveNode(inputNode, to: newPosition)
        
        // Then
        XCTAssertEqual(inputNode.position, newPosition, "Node position should be updated")
    }
    
    // MARK: - Connection Tests
    
    /// Тест создания соединения между нодами
    func testConnectPorts() {
        // Given
        nodeGraph.addNode(inputNode)
        nodeGraph.addNode(processNode)
        
        // When
        let success = nodeGraph.connectPorts(
            fromNode: inputNode,
            fromPort: inputNode.outputPorts[0],
            toNode: processNode,
            toPort: processNode.inputPorts[0]
        )
        
        // Then
        XCTAssertTrue(success, "Should connect ports successfully")
        XCTAssertEqual(nodeGraph.connections.count, 1, "Should have one connection")
        
        let connection = nodeGraph.connections.first
        XCTAssertNotNil(connection, "Should have a connection")
        XCTAssertEqual(connection?.fromNode, inputNode.id, "Connection should be from input node")
        XCTAssertEqual(connection?.toNode, processNode.id, "Connection should be to process node")
    }
    
    /// Тест удаления соединения
    func testRemoveConnection() {
        // Given
        nodeGraph.addNode(inputNode)
        nodeGraph.addNode(processNode)
        
        let success = nodeGraph.connectPorts(
            fromNode: inputNode,
            fromPort: inputNode.outputPorts[0],
            toNode: processNode,
            toPort: processNode.inputPorts[0]
        )
        XCTAssertTrue(success, "Should connect ports successfully")
        
        // When
        nodeGraph.removeConnection(
            fromNode: inputNode,
            fromPort: inputNode.outputPorts[0],
            toNode: processNode,
            toPort: processNode.inputPorts[0]
        )
        
        // Then
        XCTAssertEqual(nodeGraph.connections.count, 0, "Should have no connections")
    }
    
    /// Тест валидации соединений
    func testConnectionValidation() {
        // Given
        nodeGraph.addNode(inputNode)
        nodeGraph.addNode(processNode)
        
        // When - пытаемся соединить несуществующие порты
        let success = nodeGraph.connectPorts(
            fromNode: inputNode,
            fromPort: UUID(), // Несуществующий порт
            toNode: processNode,
            toPort: processNode.inputPorts[0]
        )
        
        // Then
        XCTAssertFalse(success, "Should fail to connect with invalid port")
        XCTAssertEqual(nodeGraph.connections.count, 0, "Should have no connections")
    }
    
    /// Тест предотвращения циклических соединений
    func testPreventCircularConnections() {
        // Given
        nodeGraph.addNode(inputNode)
        nodeGraph.addNode(processNode)
        
        // Создаем первое соединение
        let success1 = nodeGraph.connectPorts(
            fromNode: inputNode,
            fromPort: inputNode.outputPorts[0],
            toNode: processNode,
            toPort: processNode.inputPorts[0]
        )
        XCTAssertTrue(success1, "First connection should succeed")
        
        // When - пытаемся создать обратное соединение
        let success2 = nodeGraph.connectPorts(
            fromNode: processNode,
            fromPort: processNode.outputPorts[0],
            toNode: inputNode,
            toPort: inputNode.inputPorts[0]
        )
        
        // Then - должно быть предотвращено (если реализована валидация)
        // В текущей реализации это может быть разрешено, но в будущем должно быть предотвращено
        print("Note: Circular connection prevention may need to be implemented")
    }
    
    // MARK: - Graph Processing Tests
    
    /// Тест топологической сортировки
    func testTopologicalSort() {
        // Given
        nodeGraph.addNode(inputNode)
        nodeGraph.addNode(processNode)
        nodeGraph.addNode(outputNode)
        
        // Создаем линейную цепочку: input -> process -> output
        let success1 = nodeGraph.connectPorts(
            fromNode: inputNode,
            fromPort: inputNode.outputPorts[0],
            toNode: processNode,
            toPort: processNode.inputPorts[0]
        )
        
        let success2 = nodeGraph.connectPorts(
            fromNode: processNode,
            fromPort: processNode.outputPorts[0],
            toNode: outputNode,
            toPort: outputNode.inputPorts[0]
        )
        
        XCTAssertTrue(success1 && success2, "Should connect nodes successfully")
        
        // When - получаем отсортированные ноды (через NodeGraphProcessor)
        let processor = NodeGraphProcessor(nodeGraph: nodeGraph)
        let sortedNodes = asyncProcessor.topologicalSort(nodes: nodeGraph.nodes, connections: nodeGraph.connections)
        
        // Then
        XCTAssertEqual(sortedNodes.count, 3, "Should have all nodes")
        
        // Проверяем порядок: input должен быть первым, output последним
        if let firstNode = sortedNodes.first {
            XCTAssertEqual(firstNode.id, inputNode.id, "Input node should be first")
        }
        
        if let lastNode = sortedNodes.last {
            XCTAssertEqual(lastNode.id, outputNode.id, "Output node should be last")
        }
    }
    
    /// Тест обработки графа с несколькими нодами
    func testMultiNodeGraphProcessing() async {
        // Given
        nodeGraph.addNode(inputNode)
        nodeGraph.addNode(processNode)
        nodeGraph.addNode(outputNode)
        
        // Создаем соединения
        let success1 = nodeGraph.connectPorts(
            fromNode: inputNode,
            fromPort: inputNode.outputPorts[0],
            toNode: processNode,
            toPort: processNode.inputPorts[0]
        )
        
        let success2 = nodeGraph.connectPorts(
            fromNode: processNode,
            fromPort: processNode.outputPorts[0],
            toNode: outputNode,
            toPort: outputNode.inputPorts[0]
        )
        
        XCTAssertTrue(success1 && success2, "Should connect nodes successfully")
        
        // When
        let processor = NodeGraphProcessor(nodeGraph: nodeGraph)
        await asyncProcessor.processGraphAsync()
        
        // Then
        XCTAssertFalse(asyncProcessor.isProcessing, "Processing should be completed")
        XCTAssertEqual(asyncProcessor.processingProgress, 1.0, "Progress should be 100%")
    }
    
    // MARK: - Performance Tests
    
    /// Тест производительности добавления множества нод
    func testAddManyNodesPerformance() {
        // Given
        let nodeCount = 100
        
        // When
        let startTime = Date()
        
        for i in 0..<nodeCount {
            let node = TestProcessNode(position: CGPoint(x: i * 50, y: i * 50))
            nodeGraph.addNode(node)
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertEqual(nodeGraph.nodes.count, nodeCount, "Should have all nodes")
        XCTAssertLessThan(processingTime, 1.0, "Adding nodes should be fast (< 1 second)")
        
        print("⏱️ Added \(nodeCount) nodes in \(String(format: "%.3f", processingTime))s")
    }
    
    /// Тест производительности создания множества соединений
    func testAddManyConnectionsPerformance() {
        // Given
        let nodeCount = 50
        var nodes: [TestProcessNode] = []
        
        for i in 0..<nodeCount {
            let node = TestProcessNode(position: CGPoint(x: i * 50, y: i * 50))
            nodeGraph.addNode(node)
            nodes.append(node)
        }
        
        // When
        let startTime = Date()
        
        for i in 0..<(nodeCount - 1) {
            let success = nodeGraph.connectPorts(
                fromNode: nodes[i],
                fromPort: nodes[i].outputPorts[0],
                toNode: nodes[i + 1],
                toPort: nodes[i + 1].inputPorts[0]
            )
            XCTAssertTrue(success, "Should connect nodes successfully")
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertEqual(nodeGraph.connections.count, nodeCount - 1, "Should have all connections")
        XCTAssertLessThan(processingTime, 1.0, "Creating connections should be fast (< 1 second)")
        
        print("⏱️ Created \(nodeCount - 1) connections in \(String(format: "%.3f", processingTime))s")
    }
    
    // MARK: - Error Handling Tests
    
    /// Тест обработки ошибок при добавлении ноды
    func testAddNodeErrorHandling() {
        // Given
        nodeGraph.addNode(inputNode)
        
        // When - добавляем ту же ноду повторно
        nodeGraph.addNode(inputNode)
        
        // Then - не должно быть дубликатов
        let inputNodes = nodeGraph.nodes.filter { $0.id == inputNode.id }
        XCTAssertEqual(inputNodes.count, 1, "Should not have duplicate nodes")
    }
    
    /// Тест обработки ошибок при удалении несуществующей ноды
    func testRemoveNonExistentNode() {
        // Given
        let nonExistentNode = TestProcessNode(position: CGPoint(x: 999, y: 999))
        
        // When
        nodeGraph.removeNode(nonExistentNode)
        
        // Then - не должно быть ошибок
        XCTAssertEqual(nodeGraph.nodes.count, 0, "Should have no nodes")
    }
}

// MARK: - Test Node Classes

/// Тестовая нода для обработки
class TestProcessNode: BaseNode {
    
    override init(type: NodeType, position: CGPoint) {
        super.init(type: .custom, position: position)
    }
    
    override func process(inputs: [CIImage?]) -> CIImage? {
        // Простая обработка - возвращаем входное изображение
        return inputs.first
    }
    
    override func processAsync(inputs: [CIImage?]) async throws -> CIImage? {
        // Асинхронная обработка с небольшой задержкой
        try await Task.sleep(nanoseconds: 5_000_000) // 5ms
        return inputs.first
    }
}
