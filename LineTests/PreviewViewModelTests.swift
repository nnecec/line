//
//  PreviewViewModelTests.swift
//  LineTests
//

@testable import Line
import SwiftUI
import XCTest

final class PreviewViewModelTests: XCTestCase {
    private let radii = RectangleCornerRadii(
        topLeading: 8,
        bottomLeading: 8,
        bottomTrailing: 8,
        topTrailing: 8
    )

    func testCornerRadiusCacheQueriesProviderOnceForRepeatedWindow() {
        var cache = PreviewCornerRadiusCache()
        var queryCount = 0

        let first = cache.value(for: 42, isEnabled: true) { _ in
            queryCount += 1
            return radii
        }
        let second = cache.value(for: 42, isEnabled: true) { _ in
            queryCount += 1
            return radii
        }

        XCTAssertEqual(first, radii)
        XCTAssertEqual(second, radii)
        XCTAssertEqual(queryCount, 1)
    }

    func testCornerRadiusCacheCachesMissingPrivateAPIResult() {
        var cache = PreviewCornerRadiusCache()
        var queryCount = 0

        _ = cache.value(for: 42, isEnabled: true) { _ in
            queryCount += 1
            return nil
        }
        _ = cache.value(for: 42, isEnabled: true) { _ in
            queryCount += 1
            return nil
        }

        XCTAssertEqual(queryCount, 1)
    }

    func testCornerRadiusCacheRefreshesWhenTargetWindowChanges() {
        var cache = PreviewCornerRadiusCache()
        var queriedWindowIDs: [CGWindowID] = []

        _ = cache.value(for: 42, isEnabled: true) { windowID in
            queriedWindowIDs.append(windowID)
            return radii
        }
        _ = cache.value(for: 43, isEnabled: true) { windowID in
            queriedWindowIDs.append(windowID)
            return radii
        }

        XCTAssertEqual(queriedWindowIDs, [42, 43])
    }

    func testCornerRadiusCacheDoesNotQueryWhenFeatureIsDisabled() {
        var cache = PreviewCornerRadiusCache()
        var queryCount = 0

        let value = cache.value(for: 42, isEnabled: false) { _ in
            queryCount += 1
            return radii
        }

        XCTAssertNil(value)
        XCTAssertEqual(queryCount, 0)
    }
}
