//
//  NodeConnection.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 14.07.2025.
//

import SwiftUI

// MARK: - Connection Helper
struct ConnectionHelper {
    static func canConnect(from outputPort: NodePort, to inputPort: NodePort) -> Bool {
        // Only allow output->input connections
        guard outputPort.type == .output && inputPort.type == .input else {
            return false
        }
        
        // Check data type compatibility
        return outputPort.dataType == inputPort.dataType
    }
    
    static func canConnect(from outputNode: BaseNode, outputPort: NodePort, to inputNode: BaseNode, inputPort: NodePort) -> Bool {
        // Don't allow self-connections
        guard outputNode.id != inputNode.id else {
            return false
        }
        
        // Check if ports are compatible
        guard canConnect(from: outputPort, to: inputPort) else {
            return false
        }
        
        // Check if input port already has a connection (unless it supports multiple inputs)
        if !inputPort.isMultiInput {
            let existingConnections = inputNode.inputConnections.filter { connection in
                connection.toPort == inputPort.id
            }
            if !existingConnections.isEmpty {
                return false
            }
        }
        
        return true
    }
}

// MARK: - Connection Validation Result
enum ConnectionValidationResult {
    case valid
    case invalidSameNode
    case invalidPortType
    case invalidDataType
    case inputAlreadyConnected
    case wouldCreateCycle
    
    var errorMessage: String {
        switch self {
        case .valid:
            return "Connection is valid"
        case .invalidSameNode:
            return "Cannot connect node to itself"
        case .invalidPortType:
            return "Invalid port types (must be output -> input)"
        case .invalidDataType:
            return "Incompatible data types"
        case .inputAlreadyConnected:
            return "Input port already has a connection"
        case .wouldCreateCycle:
            return "Connection would create a cycle"
        }
    }
} 