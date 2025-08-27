//
//  NodeConnectionTests.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 14.07.2025.
//

import XCTest
@testable import Compositor

@MainActor
final class NodeConnectionTests: XCTestCase {
    
    var nodeGraph: NodeGraph!
    var inputNode: InputNode!
    var blurNode: BlurNode!
    var viewNode: ViewNode!
    
    override func setUp() async throws {
        nodeGraph = NodeGraph()
        
        // Создаем тестовые ноды
        inputNode = InputNode(position: CGPoint(x: 100, y: 100))
        blurNode = BlurNode(position: CGPoint(x: 300, y: 100))
        viewNode = ViewNode(position: CGPoint(x: 500, y: 100))
        
        // Добавляем ноды в граф
        nodeGraph.addNode(inputNode)
        nodeGraph.addNode(blurNode)
        nodeGraph.addNode(viewNode)
    }
    
    override func tearDown() async throws {
        nodeGraph = nil
        inputNode = nil
        blurNode = nil
        viewNode = nil
    }
    
    // MARK: - BaseNode Connection Tests
    
    func testBaseNodeConnectionMethods() {
        let connection = NodeConnection(
            fromNode: inputNode.id,
            toNode: blurNode.id,
            fromPort: inputNode.outputPorts[0].id,
            toPort: blurNode.inputPorts[0].id
        )
        
        // Тестируем добавление соединений
        inputNode.addOutputConnection(connection)
        blurNode.addInputConnection(connection)
        
        XCTAssertEqual(inputNode.outputConnections.count, 1)
        XCTAssertEqual(blurNode.inputConnections.count, 1)
        XCTAssertEqual(inputNode.outputConnections[0].id, connection.id)
        XCTAssertEqual(blurNode.inputConnections[0].id, connection.id)
        
        // Тестируем удаление конкретного соединения
        inputNode.removeOutputConnection(connection)
        blurNode.removeInputConnection(connection)
        
        XCTAssertEqual(inputNode.outputConnections.count, 0)
        XCTAssertEqual(blurNode.inputConnections.count, 0)
    }
    
    func testBaseNodeClearConnections() {
        let connection1 = NodeConnection(
            fromNode: inputNode.id,
            toNode: blurNode.id,
            fromPort: inputNode.outputPorts[0].id,
            toPort: blurNode.inputPorts[0].id
        )
        
        let connection2 = NodeConnection(
            fromNode: blurNode.id,
            toNode: viewNode.id,
            fromPort: blurNode.outputPorts[0].id,
            toPort: viewNode.inputPorts[0].id
        )
        
        // Добавляем соединения
        inputNode.addOutputConnection(connection1)
        blurNode.addInputConnection(connection1)
        blurNode.addOutputConnection(connection2)
        viewNode.addInputConnection(connection2)
        
        // Проверяем, что соединения добавлены
        XCTAssertEqual(inputNode.outputConnections.count, 1)
        XCTAssertEqual(blurNode.inputConnections.count, 1)
        XCTAssertEqual(blurNode.outputConnections.count, 1)
        XCTAssertEqual(viewNode.inputConnections.count, 1)
        
        // Очищаем все соединения
        inputNode.clearAllConnections()
        blurNode.clearAllConnections()
        viewNode.clearAllConnections()
        
        // Проверяем, что все соединения удалены
        XCTAssertEqual(inputNode.outputConnections.count, 0)
        XCTAssertEqual(blurNode.inputConnections.count, 0)
        XCTAssertEqual(blurNode.outputConnections.count, 0)
        XCTAssertEqual(viewNode.inputConnections.count, 0)
    }
    
    // MARK: - NodeGraph Connection Tests
    
    func testNodeGraphConnectPorts() {
        let fromPort = inputNode.outputPorts[0]
        let toPort = blurNode.inputPorts[0]
        
        // Создаем соединение через NodeGraph
        let success = nodeGraph.connectPorts(
            fromNode: inputNode,
            fromPort: fromPort,
            toNode: blurNode,
            toPort: toPort
        )
        
        XCTAssertTrue(success)
        XCTAssertEqual(nodeGraph.connections.count, 1)
        XCTAssertEqual(inputNode.outputConnections.count, 1)
        XCTAssertEqual(blurNode.inputConnections.count, 1)
    }
    
    func testNodeGraphRemoveConnection() {
        let fromPort = inputNode.outputPorts[0]
        let toPort = blurNode.inputPorts[0]
        
        // Создаем соединение
        let success = nodeGraph.connectPorts(
            fromNode: inputNode,
            fromPort: fromPort,
            toNode: blurNode,
            toPort: toPort
        )
        
        XCTAssertTrue(success)
        XCTAssertEqual(nodeGraph.connections.count, 1)
        
        // Удаляем соединение
        let connection = nodeGraph.connections[0]
        nodeGraph.removeConnection(connection)
        
        XCTAssertEqual(nodeGraph.connections.count, 0)
        XCTAssertEqual(inputNode.outputConnections.count, 0)
        XCTAssertEqual(blurNode.inputConnections.count, 0)
    }
    
    func testNodeGraphRemoveNodeConnections() {
        let fromPort = inputNode.outputPorts[0]
        let toPort = blurNode.inputPorts[0]
        
        // Создаем соединение
        let success = nodeGraph.connectPorts(
            fromNode: inputNode,
            fromPort: fromPort,
            toNode: blurNode,
            toPort: toPort
        )
        
        XCTAssertTrue(success)
        XCTAssertEqual(nodeGraph.connections.count, 1)
        
        // Удаляем все соединения ноды
        nodeGraph.removeNodeConnections(inputNode)
        
        XCTAssertEqual(nodeGraph.connections.count, 0)
        XCTAssertEqual(inputNode.outputConnections.count, 0)
        XCTAssertEqual(blurNode.inputConnections.count, 0)
    }
    
    func testNodeGraphClearAllConnections() {
        let fromPort1 = inputNode.outputPorts[0]
        let toPort1 = blurNode.inputPorts[0]
        let fromPort2 = blurNode.outputPorts[0]
        let toPort2 = viewNode.inputPorts[0]
        
        // Создаем два соединения
        let success1 = nodeGraph.connectPorts(
            fromNode: inputNode,
            fromPort: fromPort1,
            toNode: blurNode,
            toPort: toPort1
        )
        
        let success2 = nodeGraph.connectPorts(
            fromNode: blurNode,
            fromPort: fromPort2,
            toNode: viewNode,
            toPort: toPort2
        )
        
        XCTAssertTrue(success1)
        XCTAssertTrue(success2)
        XCTAssertEqual(nodeGraph.connections.count, 2)
        
        // Очищаем все соединения
        nodeGraph.clearAllConnections()
        
        XCTAssertEqual(nodeGraph.connections.count, 0)
        XCTAssertEqual(inputNode.outputConnections.count, 0)
        XCTAssertEqual(blurNode.inputConnections.count, 0)
        XCTAssertEqual(blurNode.outputConnections.count, 0)
        XCTAssertEqual(viewNode.inputConnections.count, 0)
    }
    
    func testNodeGraphRemoveConnectionsToPort() {
        let fromPort = inputNode.outputPorts[0]
        let toPort = blurNode.inputPorts[0]
        
        // Создаем соединение
        let success = nodeGraph.connectPorts(
            fromNode: inputNode,
            fromPort: fromPort,
            toNode: blurNode,
            toPort: toPort
        )
        
        XCTAssertTrue(success)
        XCTAssertEqual(nodeGraph.connections.count, 1)
        
        // Удаляем соединения к порту
        nodeGraph.removeConnectionsToPort(nodeId: inputNode.id, portId: fromPort.id)
        
        XCTAssertEqual(nodeGraph.connections.count, 0)
        XCTAssertEqual(inputNode.outputConnections.count, 0)
        XCTAssertEqual(blurNode.inputConnections.count, 0)
    }
    
    // MARK: - Integration Tests
    
    func testNodeGraphViewModelIntegration() {
        let nodeGraph = NodeGraph()
        let viewModel = NodeGraphViewModel(nodeGraph: nodeGraph)
        
        // Добавляем ноды в ViewModel
        viewModel.addNode(inputNode)
        viewModel.addNode(blurNode)
        
        let fromPort = inputNode.outputPorts[0]
        let toPort = blurNode.inputPorts[0]
        
        // Создаем соединение через ViewModel
        let success = viewModel.connectNodes(
            fromNode: inputNode,
            fromPort: fromPort,
            toNode: blurNode,
            toPort: toPort
        )
        
        XCTAssertTrue(success)
        XCTAssertEqual(viewModel.connections.count, 1)
        
        // Удаляем соединение через ViewModel
        let connection = viewModel.connections[0]
        viewModel.removeConnection(connection)
        
        XCTAssertEqual(viewModel.connections.count, 0)
        XCTAssertEqual(inputNode.outputConnections.count, 0)
        XCTAssertEqual(blurNode.inputConnections.count, 0)
    }
    
    // MARK: - Validation Tests
    
    func testConnectionValidation() {
        let fromPort = inputNode.outputPorts[0]
        let toPort = blurNode.inputPorts[0]
        
        // Тестируем валидное соединение
        let success = nodeGraph.connectPorts(
            fromNode: inputNode,
            fromPort: fromPort,
            toNode: blurNode,
            toPort: toPort
        )
        
        XCTAssertTrue(success)
        
        // Тестируем попытку соединения ноды с самой собой
        let selfConnectionSuccess = nodeGraph.connectPorts(
            fromNode: inputNode,
            fromPort: fromPort,
            toNode: inputNode,
            toPort: toPort
        )
        
        XCTAssertFalse(selfConnectionSuccess)
    }
    
    func testDuplicateConnectionPrevention() {
        let fromPort = inputNode.outputPorts[0]
        let toPort = blurNode.inputPorts[0]
        
        // Создаем первое соединение
        let success1 = nodeGraph.connectPorts(
            fromNode: inputNode,
            fromPort: fromPort,
            toNode: blurNode,
            toPort: toPort
        )
        
        XCTAssertTrue(success1)
        XCTAssertEqual(nodeGraph.connections.count, 1)
        
        // Пытаемся создать дублирующее соединение
        let success2 = nodeGraph.connectPorts(
            fromNode: inputNode,
            fromPort: fromPort,
            toNode: blurNode,
            toPort: toPort
        )
        
        XCTAssertTrue(success2) // Должно заменить существующее соединение
        XCTAssertEqual(nodeGraph.connections.count, 1) // Только одно соединение
    }
}
