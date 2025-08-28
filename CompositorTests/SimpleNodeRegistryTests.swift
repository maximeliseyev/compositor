//
//  SimpleNodeRegistryTests.swift
//  CompositorTests
//
//  Created by Maxim Eliseyev on 14.07.2025.
//

import XCTest
@testable import Compositor

@MainActor
final class SimpleNodeRegistryTests: XCTestCase {
    
    func testNodeRegistryExists() throws {
        // Проверяем, что NodeRegistry доступен
        let registry = NodeRegistry.shared
        XCTAssertNotNil(registry)
    }
    
    func testNodeTypesExist() throws {
        // Проверяем, что NodeType enum доступен
        let blurType = NodeType.blur
        let brightnessType = NodeType.brightness
        let inputType = NodeType.input
        let viewType = NodeType.view
        
        XCTAssertEqual(blurType.rawValue, "Blur")
        XCTAssertEqual(brightnessType.rawValue, "Brightness")
        XCTAssertEqual(inputType.rawValue, "Input")
        XCTAssertEqual(viewType.rawValue, "View")
    }
    
    func testBaseNodeExists() throws {
        // Проверяем, что BaseNode доступен
        let position = CGPoint(x: 100, y: 100)
        let node = BaseNode(type: .input, position: position)
        
        XCTAssertNotNil(node)
        XCTAssertEqual(node.type, .input)
        XCTAssertEqual(node.position, position)
    }
    
    func testCoreImageNodeExists() throws {
        // Проверяем, что CoreImageNode доступен
        let position = CGPoint(x: 200, y: 200)
        let node = CoreImageNode(type: .blur, position: position)
        
        XCTAssertNotNil(node)
        XCTAssertTrue(node is CoreImageNode)
        XCTAssertTrue(node is BaseNode)
    }
    
    func testBlurNodeExists() throws {
        // Проверяем, что BlurNode доступен
        let position = CGPoint(x: 300, y: 300)
        let node = BlurNode(type: .blur, position: position)
        
        XCTAssertNotNil(node)
        XCTAssertTrue(node is BlurNode)
        XCTAssertTrue(node is CoreImageNode)
        XCTAssertTrue(node is BaseNode)
    }
    
    func testBrightnessNodeExists() throws {
        // Проверяем, что BrightnessNode доступен
        let position = CGPoint(x: 400, y: 400)
        let node = BrightnessNode(type: .brightness, position: position)
        
        XCTAssertNotNil(node)
        XCTAssertTrue(node is BrightnessNode)
        XCTAssertTrue(node is CoreImageNode)
        XCTAssertTrue(node is BaseNode)
    }
    
    func testNodeFactoryExists() throws {
        // Проверяем, что NodeFactory доступен
        let position = CGPoint(x: 500, y: 500)
        let node = NodeFactory.createNode(type: .blur, position: position)
        
        XCTAssertNotNil(node)
        XCTAssertTrue(node is BlurNode)
    }
}
