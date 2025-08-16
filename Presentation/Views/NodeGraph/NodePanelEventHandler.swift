//
//  NodeGraphEventHandler.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 17.07.2025.
//

import SwiftUI
import AppKit
import Foundation

/// Обрабатывает события мыши и клавиатуры для NodeGraph панели
struct NodePanelEventHandler: NSViewRepresentable {
    var onCreateNode: (NodeType, CGPoint) -> Void
    var onDelete: () -> Void
    var onDeselectAll: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = EventHandlerView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let view = nsView as! EventHandlerView
        view.coordinator = context.coordinator
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onCreateNode: onCreateNode,
            onDelete: onDelete,
            onDeselectAll: onDeselectAll
        )
    }

    class Coordinator: NSObject, NSMenuDelegate {
        var onCreateNode: (NodeType, CGPoint) -> Void
        var onDelete: () -> Void
        var onDeselectAll: () -> Void

        init(onCreateNode: @escaping (NodeType, CGPoint) -> Void, onDelete: @escaping () -> Void, onDeselectAll: @escaping () -> Void) {
            self.onCreateNode = onCreateNode
            self.onDelete = onDelete
            self.onDeselectAll = onDeselectAll
        }

        func showContextMenu(at point: NSPoint, with event: NSEvent, in view: NSView) {
            let menu = NSMenu()
            
            // Add search field (placeholder for now)
            let searchItem = NSMenuItem()
            let searchField = NSSearchField()
            searchField.frame = NSRect(x: 0, y: 0, width: 200, height: 20)
            searchField.placeholderString = "Search nodes..."
            searchField.isEnabled = false // Disable for now, will implement search later
            searchItem.view = searchField
            menu.addItem(searchItem)
            menu.addItem(NSMenuItem.separator())
            
            // Group nodes by category
            let categories = NodeCategory.allCases
            for (index, category) in categories.enumerated() {
                let nodesInCategory = NodeType.allCases.filter { $0.category == category }
                
                if !nodesInCategory.isEmpty {
                    // Add category header
                    let categoryItem = NSMenuItem(title: category.displayName, action: nil, keyEquivalent: "")
                    categoryItem.isEnabled = false
                    let font = NSFont.systemFont(ofSize: 10, weight: .medium)
                    categoryItem.attributedTitle = NSAttributedString(
                        string: category.displayName,
                        attributes: [
                            .font: font,
                            .foregroundColor: NSColor.secondaryLabelColor
                        ]
                    )
                    menu.addItem(categoryItem)
                    
                    for nodeType in nodesInCategory {
                        let item = NSMenuItem(
                            title: nodeType.displayName,
                            action: #selector(menuItemSelected(_:)),
                            keyEquivalent: ""
                        )
                        item.representedObject = nodeType.rawValue
                        item.target = self
                        
                        let attributedTitle = NSAttributedString(
                            string: nodeType.displayName,
                            attributes: [
                                .font: NSFont.systemFont(ofSize: 12, weight: .regular)
                            ]
                        )
                        item.attributedTitle = attributedTitle
                        menu.addItem(item)
                    }
                    
                    if index < categories.count - 1 {
                        menu.addItem(NSMenuItem.separator())
                    }
                }
            }
            
            menu.delegate = self
            objc_setAssociatedObject(menu, &Coordinator.menuLocationKey, NSValue(point: point), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            NSMenu.popUpContextMenu(menu, with: event, for: view)
        }

        @objc func menuItemSelected(_ sender: NSMenuItem) {
            guard let menu = sender.menu,
                  let value = objc_getAssociatedObject(menu, &Coordinator.menuLocationKey) as? NSValue,
                  let typeRaw = sender.representedObject as? String,
                  let type = NodeType(rawValue: typeRaw) else { return }
            
            let location = value.pointValue
            let swiftUIPoint = CGPoint(x: location.x, y: location.y)
            onCreateNode(type, swiftUIPoint)
        }

        static var menuLocationKey: UInt8 = 0
    }
    
    class EventHandlerView: NSView {
        weak var coordinator: Coordinator?
        
        override func rightMouseDown(with event: NSEvent) {
            let point = convert(event.locationInWindow, from: nil)
            coordinator?.showContextMenu(at: point, with: event, in: self)
        }
        
        override func mouseDown(with event: NSEvent) {
            coordinator?.onDeselectAll()
            super.mouseDown(with: event)
        }
        
        override func keyDown(with event: NSEvent) {
            if event.keyCode == 51 || event.keyCode == 117 { // delete keys
                coordinator?.onDelete()
                return
            }
            super.keyDown(with: event)
        }
        
        override var acceptsFirstResponder: Bool {
            return true
        }
        
        override func viewDidMoveToWindow() {
            window?.makeFirstResponder(self)
        }
    }
} 