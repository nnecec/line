//
//  LightweightWindowInfoTests.swift
//  LineTests
//
//  Pure unit tests for WindowUtility.lightweightInfo filter/parser.
//

import XCTest
@testable import Line

final class LightweightWindowInfoTests: XCTestCase {

    // MARK: - Helpers

    private func windowInfo(
        windowID: CGWindowID = 42,
        pid: pid_t = 1234,
        alpha: Double = 1.0,
        layer: CGWindowLevel? = kCGNormalWindowLevel,
        frame: CGRect? = CGRect(x: 10, y: 20, width: 300, height: 200)
    ) -> [String: AnyObject] {
        var info: [String: AnyObject] = [
            kCGWindowNumber as String: NSNumber(value: windowID),
            kCGWindowOwnerPID as String: NSNumber(value: pid),
            kCGWindowAlpha as String: NSNumber(value: alpha)
        ]

        if let layer {
            info[kCGWindowLayer as String] = NSNumber(value: layer)
        }

        if let frame {
            info[kCGWindowBounds as String] = [
                "X": frame.origin.x,
                "Y": frame.origin.y,
                "Width": frame.width,
                "Height": frame.height
            ] as NSDictionary
        }

        return info
    }

    // MARK: - Accepts valid entries

    func testLightweightInfoParsesValidWindow() {
        let frame = CGRect(x: 100, y: 50, width: 640, height: 480)
        let info = windowInfo(windowID: 7, pid: 99, alpha: 0.9, frame: frame)

        let result = WindowUtility.lightweightInfo(from: info)

        XCTAssertEqual(result?.cgWindowID, 7)
        XCTAssertEqual(result?.ownerPID, 99)
        XCTAssertEqual(result?.frame, frame)
    }

    func testLightweightInfoAcceptsMissingLayer() {
        let info = windowInfo(layer: nil)

        let result = WindowUtility.lightweightInfo(from: info)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.cgWindowID, 42)
    }

    func testLightweightInfoAcceptsDraggingLayer() {
        let info = windowInfo(layer: kCGDraggingWindowLevel)

        XCTAssertNotNil(WindowUtility.lightweightInfo(from: info))
    }

    // MARK: - Filters

    func testLightweightInfoRejectsInvisibleAlpha() {
        let info = windowInfo(alpha: 0.01)

        XCTAssertNil(WindowUtility.lightweightInfo(from: info))
    }

    func testLightweightInfoRejectsZeroAlpha() {
        let info = windowInfo(alpha: 0)

        XCTAssertNil(WindowUtility.lightweightInfo(from: info))
    }

    func testLightweightInfoRejectsLayerBelowNormal() {
        let info = windowInfo(layer: kCGNormalWindowLevel - 1)

        XCTAssertNil(WindowUtility.lightweightInfo(from: info))
    }

    func testLightweightInfoRejectsLayerAboveDragging() {
        let info = windowInfo(layer: kCGDraggingWindowLevel + 1)

        XCTAssertNil(WindowUtility.lightweightInfo(from: info))
    }

    func testLightweightInfoRejectsMissingBounds() {
        let info = windowInfo(frame: nil)

        XCTAssertNil(WindowUtility.lightweightInfo(from: info))
    }

    func testLightweightInfoRejectsMissingWindowID() {
        var info = windowInfo()
        info.removeValue(forKey: kCGWindowNumber as String)

        XCTAssertNil(WindowUtility.lightweightInfo(from: info))
    }

    func testLightweightInfoRejectsMissingPID() {
        var info = windowInfo()
        info.removeValue(forKey: kCGWindowOwnerPID as String)

        XCTAssertNil(WindowUtility.lightweightInfo(from: info))
    }

    // MARK: - Equatable

    func testLightweightWindowInfoEquatable() {
        let a = LightweightWindowInfo(
            cgWindowID: 1,
            frame: CGRect(x: 0, y: 0, width: 10, height: 10),
            ownerPID: 100
        )
        let b = LightweightWindowInfo(
            cgWindowID: 1,
            frame: CGRect(x: 0, y: 0, width: 10, height: 10),
            ownerPID: 100
        )
        let c = LightweightWindowInfo(
            cgWindowID: 2,
            frame: CGRect(x: 0, y: 0, width: 10, height: 10),
            ownerPID: 100
        )

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - List API smoke (no AX)

    func testLightweightWindowListDoesNotCrash() {
        // Live CG list; may be empty under headless CI. Must not throw or hang.
        let list = WindowUtility.lightweightWindowList()
        XCTAssertGreaterThanOrEqual(list.count, 0)
        for item in list {
            XCTAssertGreaterThan(item.frame.width, 0)
            XCTAssertGreaterThan(item.frame.height, 0)
            XCTAssertNotEqual(item.cgWindowID, 0)
        }
    }
}
