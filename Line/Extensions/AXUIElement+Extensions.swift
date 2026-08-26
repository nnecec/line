//
//  AXUIElement+Extensions.swift
//  Line
//
//  Created by nnecec on 2023-06-16.
//

import SwiftUI

enum AXValueBoundaryPolicy {
    static func isAXUIElement(_ value: AnyObject) -> Bool {
        CFGetTypeID(value) == AXUIElementGetTypeID()
    }

    static func isAXValue(_ value: AnyObject) -> Bool {
        CFGetTypeID(value) == AXValueGetTypeID()
    }
}

enum AXValueBoundaryAdapter {
    typealias GetValue = (AXValue, AXValueType, UnsafeMutableRawPointer) -> Bool

    static func unpack(_ value: AnyObject, getValue: GetValue = AXValueGetValue) throws -> Any {
        switch CFGetTypeID(value) {
        case AXUIElementGetTypeID():
            return try checkedAXUIElement(value)
        case AXValueGetTypeID():
            let axValue = try checkedAXValue(value)
            let type = AXValueGetType(axValue)
            switch type {
            case .axError:
                var result: AXError = .success
                guard getValue(axValue, type, &result) else {
                    throw AXError.illegalArgument
                }
                return result
            case .cfRange:
                var result = CFRange()
                guard getValue(axValue, type, &result) else {
                    throw AXError.illegalArgument
                }
                return result
            case .cgPoint:
                var result = CGPoint.zero
                guard getValue(axValue, type, &result) else {
                    throw AXError.illegalArgument
                }
                return result
            case .cgRect:
                var result = CGRect.zero
                guard getValue(axValue, type, &result) else {
                    throw AXError.illegalArgument
                }
                return result
            case .cgSize:
                var result = CGSize.zero
                guard getValue(axValue, type, &result) else {
                    throw AXError.illegalArgument
                }
                return result
            default:
                return value
            }
        default:
            return value
        }
    }

    private static func checkedAXUIElement(_ value: AnyObject) throws -> AXUIElement {
        guard AXValueBoundaryPolicy.isAXUIElement(value) else {
            throw AXError.illegalArgument
        }

        // AXUIElement is an opaque Core Foundation type. Swift imports it as a
        // CF-backed class, so a conditional cast from AnyObject is rejected as
        // always-successful by the compiler. The CFTypeID guard above proves
        // the representation before this narrow conversion.
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private static func checkedAXValue(_ value: AnyObject) throws -> AXValue {
        guard AXValueBoundaryPolicy.isAXValue(value) else {
            throw AXError.illegalArgument
        }

        // See checkedAXUIElement(_:): AXValue is also an opaque CF type.
        return unsafeBitCast(value, to: AXValue.self)
    }
}

extension AXUIElement {
    static let systemWide = AXUIElementCreateSystemWide()

    func getValue<T>(_ attribute: NSAccessibility.Attribute) throws -> T? {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(self, attribute as CFString, &value)

        if error == .noValue || error == .attributeUnsupported {
            return nil
        }

        guard error == .success else {
            throw error
        }

        guard let value else {
            throw AXError.noValue
        }

        let unpacked = try AXValueBoundaryAdapter.unpack(value)
        guard let unpackedValue = unpacked as? T else {
            throw AXError.illegalArgument
        }

        return unpackedValue
    }

    func setValue(_ attribute: NSAccessibility.Attribute, value: Any) throws {
        let error = AXUIElementSetAttributeValue(self, attribute as CFString, packAXValue(value))

        guard error == .success else {
            throw error
        }
    }

    func canSetValue(_ attribute: NSAccessibility.Attribute) throws -> Bool {
        var isSettable = DarwinBoolean(false)
        let error = AXUIElementIsAttributeSettable(self, attribute as CFString, &isSettable)
        guard error == .success else {
            throw error
        }
        return isSettable.boolValue
    }

    func getElementAtPosition(_ position: CGPoint) throws -> AXUIElement? {
        var element: AXUIElement?
        let error = AXUIElementCopyElementAtPosition(self, Float(position.x), Float(position.y), &element)

        guard error == .success else {
            throw error
        }

        return element
    }

    /// Only used when experimenting :)
    func getAttributeNames() -> [String]? {
        var ref: CFArray?
        let error = AXUIElementCopyAttributeNames(self, &ref)
        if error == .success {
            return ref! as [AnyObject] as? [String]
        }
        return nil
    }

    private func packAXValue(_ value: Any) -> AnyObject {
        switch value {
        case let val as Window:
            val.axWindow
        case let val as Bool:
            val as CFBoolean
        case var val as CFRange:
            AXValueCreate(AXValueType(rawValue: kAXValueCFRangeType)!, &val)!
        case var val as CGPoint:
            AXValueCreate(AXValueType(rawValue: kAXValueCGPointType)!, &val)!
        case var val as CGRect:
            AXValueCreate(AXValueType(rawValue: kAXValueCGRectType)!, &val)!
        case var val as CGSize:
            AXValueCreate(AXValueType(rawValue: kAXValueCGSizeType)!, &val)!
        default:
            value as AnyObject
        }
    }

    func getPID() throws -> pid_t {
        var pid: pid_t = 0
        let error = AXUIElementGetPid(self, &pid)

        guard error == .success else {
            throw error
        }

        return pid
    }

    func getWindowID() throws -> CGWindowID {
        guard let AXUIElementGetWindow = PrivateSymbolLoader.AXUIElementGetWindow else {
            // Symbol missing on this OS build — fail like other AX errors so callers degrade.
            throw AXError.failure
        }

        var id: CGWindowID = 0
        let error = AXUIElementGetWindow(self, &id)

        guard error == .success else {
            throw error
        }

        return id
    }

    func performAction(_ action: NSAccessibility.Action) throws {
        let error = AXUIElementPerformAction(self, action as CFString)

        guard error == .success else {
            throw error
        }
    }

    var children: [AXUIElement] {
        let children: [AXUIElement]? = try? getValue(.children)
        return children ?? []
    }
}

extension AXError: @retroactive _BridgedNSError {}
extension AXError: @retroactive _ObjectiveCBridgeableError {}
extension AXError: Swift.Error {}

extension NSAccessibility.Attribute {
    static let fullScreen: NSAccessibility.Attribute = .init(rawValue: "AXFullScreen")
    static let enhancedUserInterface = NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface")
    static let windowIds = NSAccessibility.Attribute(rawValue: "AXWindowsIDs")
}
