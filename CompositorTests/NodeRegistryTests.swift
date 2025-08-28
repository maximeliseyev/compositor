//
//  NodeRegistryTests.swift
//  CompositorTests
//
//  Created by Maxim Eliseyev on 14.07.2025.
//

import XCTest
@testable import Compositor

@MainActor
final class NodeRegistryTests: XCTestCase {
    
    var nodeRegistry: NodeRegistry!
    
    override func setUpWithError() throws {
        nodeRegistry = NodeRegistry.shared
    }
    
    override func tearDownWithError() throws {
        nodeRegistry = nil
    }
    
    // MARK: - Node Creation Tests
    
    func testCreateBlurNode() throws {
        let position = CGPoint(x: 100, y: 100)
        let blurNode = nodeRegistry.createNode(type: .blur, position: position)
        
        XCTAssertNotNil(blurNode)
        XCTAssertEqual(blurNode.type, .blur)
        XCTAssertEqual(blurNode.position, position)
        XCTAssertTrue(blurNode is BlurNode)
        XCTAssertTrue(blurNode is CoreImageNode)
    }
    
    func testCreateBrightnessNode() throws {
        let position = CGPoint(x: 200, y: 200)
        let brightnessNode = nodeRegistry.createNode(type: .brightness, position: position)
        
        XCTAssertNotNil(brightnessNode)
        XCTAssertEqual(brightnessNode.type, .brightness)
        XCTAssertEqual(brightnessNode.position, position)
        XCTAssertTrue(brightnessNode is BrightnessNode)
        XCTAssertTrue(brightnessNode is CoreImageNode)
    }
    
    func testCreateInputNode() throws {
        let position = CGPoint(x: 300, y: 300)
        let inputNode = nodeRegistry.createNode(type: .input, position: position)
        
        XCTAssertNotNil(inputNode)
        XCTAssertEqual(inputNode.type, .input)
        XCTAssertEqual(inputNode.position, position)
        XCTAssertTrue(inputNode is InputNode)
    }
    
    func testCreateViewNode() throws {
        let position = CGPoint(x: 400, y: 400)
        let viewNode = nodeRegistry.createNode(type: .view, position: position)
        
        XCTAssertNotNil(viewNode)
        XCTAssertEqual(viewNode.type, .view)
        XCTAssertEqual(viewNode.position, position)
        XCTAssertTrue(viewNode is ViewNode)
    }
    
    // MARK: - Node Type Support Tests
    
    func testSupportedNodeTypes() throws {
        let supportedTypes = nodeRegistry.getRegisteredNodeTypes()
        
        XCTAssertTrue(supportedTypes.contains(.blur))
        XCTAssertTrue(supportedTypes.contains(.brightness))
        XCTAssertTrue(supportedTypes.contains(.input))
        XCTAssertTrue(supportedTypes.contains(.view))
    }
    
    func testNodeTypeSupport() throws {
        XCTAssertTrue(nodeRegistry.isNodeTypeSupported(.blur))
        XCTAssertTrue(nodeRegistry.isNodeTypeSupported(.brightness))
        XCTAssertTrue(nodeRegistry.isNodeTypeSupported(.input))
        XCTAssertTrue(nodeRegistry.isNodeTypeSupported(.view))
    }
    
    // MARK: - Default Parameters Tests
    
    func testDefaultParametersForBlur() throws {
        let params = nodeRegistry.getDefaultParameters(for: .blur)
        
        XCTAssertNotNil(params["radius"])
        XCTAssertNotNil(params["intensity"])
        XCTAssertEqual(params["radius"] as? Double, 10.0)
        XCTAssertEqual(params["intensity"] as? Double, 1.0)
    }
    
    func testDefaultParametersForBrightness() throws {
        let params = nodeRegistry.getDefaultParameters(for: .brightness)
        
        XCTAssertNotNil(params["brightness"])
        XCTAssertNotNil(params["contrast"])
        XCTAssertNotNil(params["saturation"])
        XCTAssertEqual(params["brightness"] as? Double, 0.0)
        XCTAssertEqual(params["contrast"] as? Double, 1.0)
        XCTAssertEqual(params["saturation"] as? Double, 1.0)
    }
    
    // MARK: - Inspector Creation Tests
    
    func testCreateInspectorForBlurNode() throws {
        let blurNode = BlurNode(type: .blur, position: .zero)
        let inspector = nodeRegistry.createInspector(for: blurNode)
        
        XCTAssertNotNil(inspector)
    }
    
    func testCreateInspectorForBrightnessNode() throws {
        let brightnessNode = BrightnessNode(type: .brightness, position: .zero)
        let inspector = nodeRegistry.createInspector(for: brightnessNode)
        
        XCTAssertNotNil(inspector)
    }
    
    func testCreateInspectorForInputNode() throws {
        let inputNode = InputNode(position: .zero)
        let inspector = nodeRegistry.createInspector(for: inputNode)
        
        XCTAssertNotNil(inspector)
    }
    
    // MARK: - Node Factory Integration Tests
    
    func testNodeFactoryIntegration() throws {
        let position = CGPoint(x: 500, y: 500)
        
        // Test blur node creation through factory
        let blurNode = NodeFactory.createNode(type: .blur, position: position)
        XCTAssertTrue(blurNode is BlurNode)
        XCTAssertEqual(blurNode.position, position)
        
        // Test brightness node creation through factory
        let brightnessNode = NodeFactory.createNode(type: .brightness, position: position)
        XCTAssertTrue(brightnessNode is BrightnessNode)
        XCTAssertEqual(brightnessNode.position, position)
    }
    
    func testNodeFactoryWithCustomParameters() throws {
        let position = CGPoint(x: 600, y: 600)
        let customParams = ["radius": 25.0, "intensity": 0.8]
        
        let blurNode = NodeFactory.createNode(type: .blur, position: position, parameters: customParams)
        
        XCTAssertTrue(blurNode is BlurNode)
        XCTAssertEqual(blurNode.getParameter(key: "radius") as? Double, 25.0)
        XCTAssertEqual(blurNode.getParameter(key: "intensity") as? Double, 0.8)
    }
    
    // MARK: - Performance Tests
    
    func testNodeCreationPerformance() throws {
        measure {
            for _ in 0..<100 {
                let position = CGPoint(x: Double.random(in: 0...1000), y: Double.random(in: 0...1000))
                _ = nodeRegistry.createNode(type: .blur, position: position)
            }
        }
    }
    
    func testInspectorCreationPerformance() throws {
        let blurNode = BlurNode(type: .blur, position: .zero)
        
        measure {
            for _ in 0..<100 {
                _ = nodeRegistry.createInspector(for: blurNode)
            }
        }
    }
    
    // MARK: - Architecture Validation Tests
    
    func testNoSwitchCaseInNodeFactory() throws {
        // Проверяем, что NodeFactory больше не использует switch-case
        let factorySource = try String(contentsOfFile: "Domain/Services/NodeFactory.swift")
        
        // Ищем switch-case паттерны
        let switchPatterns = [
            "switch type",
            "case .blur:",
            "case .brightness:",
            "case .input:",
            "case .view:"
        ]
        
        for pattern in switchPatterns {
            XCTAssertFalse(factorySource.contains(pattern), "NodeFactory still contains switch-case pattern: \(pattern)")
        }
        
        // Проверяем, что используется NodeRegistry
        XCTAssertTrue(factorySource.contains("NodeRegistry.shared"))
    }
    
    func testNoSwitchCaseInNodeGraphPanel() throws {
        // Проверяем, что NodeGraphPanel больше не использует switch-case для создания нод
        let panelSource = try String(contentsOfFile: "Presentation/Views/NodeGraph/NodeGraphPanel.swift")
        
        // Ищем switch-case паттерны для создания нод
        let switchPatterns = [
            "switch type",
            "case .blur:",
            "case .brightness:",
            "case .input:",
            "case .view:"
        ]
        
        for pattern in switchPatterns {
            XCTAssertFalse(panelSource.contains(pattern), "NodeGraphPanel still contains switch-case pattern: \(pattern)")
        }
        
        // Проверяем, что используется NodeFactory
        XCTAssertTrue(panelSource.contains("NodeFactory.createNode"))
    }
    
    func testNoSwitchCaseInNodeInspectorFactory() throws {
        // Проверяем, что NodeInspectorFactory больше не использует switch-case
        let inspectorSource = try String(contentsOfFile: "Presentation/Views/Inspector/NodeInspectors.swift")
        
        // Ищем switch-case паттерны
        let switchPatterns = [
            "switch node",
            "case let blurNode as BlurNode:",
            "case let brightnessNode as BrightnessNode:",
            "case let inputNode as InputNode:",
            "case let viewNode as ViewNode:"
        ]
        
        for pattern in switchPatterns {
            XCTAssertFalse(inspectorSource.contains(pattern), "NodeInspectorFactory still contains switch-case pattern: \(pattern)")
        }
        
        // Проверяем, что используется NodeRegistry
        XCTAssertTrue(inspectorSource.contains("NodeRegistry.shared"))
    }
}
