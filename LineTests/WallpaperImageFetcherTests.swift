//
//  WallpaperImageFetcherTests.swift
//  LineTests
//

import CoreGraphics
@testable import Line
import XCTest

final class WallpaperImageFetcherTests: XCTestCase {
    func testWallpaperWindowIDsReturnsMatchingDockWallpaperWindow() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let windows = [
            wallpaperWindow(id: 42, frame: screenFrame)
        ]

        let ids = WallpaperImageFetcher.wallpaperWindowIDs(
            from: windows,
            screenFrame: screenFrame,
            matchFrame: true
        )

        XCTAssertEqual(ids, [42])
    }

    func testWallpaperWindowIDsSkipsEntriesMissingWindowNumber() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let windows = [
            wallpaperWindow(id: nil, frame: screenFrame)
        ]

        let ids = WallpaperImageFetcher.wallpaperWindowIDs(
            from: windows,
            screenFrame: screenFrame,
            matchFrame: true
        )

        XCTAssertTrue(ids.isEmpty)
    }

    func testWallpaperWindowIDsIgnoresNonDockAndNonWallpaperWindows() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let windows = [
            wallpaperWindow(id: 1, ownerName: "Finder", frame: screenFrame),
            wallpaperWindow(id: 2, windowName: "Desktop", frame: screenFrame)
        ]

        let ids = WallpaperImageFetcher.wallpaperWindowIDs(
            from: windows,
            screenFrame: screenFrame,
            matchFrame: false
        )

        XCTAssertTrue(ids.isEmpty)
    }

    func testWallpaperWindowIDsMatchFrameFiltersOtherDisplays() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let otherFrame = CGRect(x: 1440, y: 0, width: 1440, height: 900)
        let windows = [
            wallpaperWindow(id: 10, frame: screenFrame),
            wallpaperWindow(id: 11, frame: otherFrame)
        ]

        let ids = WallpaperImageFetcher.wallpaperWindowIDs(
            from: windows,
            screenFrame: screenFrame,
            matchFrame: true
        )

        XCTAssertEqual(ids, [10])
    }

    func testWallpaperWindowIDsWithoutFrameMatchAcceptsAnyDockWallpaperWindow() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let otherFrame = CGRect(x: 1440, y: 0, width: 1440, height: 900)
        let windows = [
            wallpaperWindow(id: 99, frame: otherFrame)
        ]

        let ids = WallpaperImageFetcher.wallpaperWindowIDs(
            from: windows,
            screenFrame: screenFrame,
            matchFrame: false
        )

        XCTAssertEqual(ids, [99])
    }

    private func wallpaperWindow(
        id: CGWindowID?,
        ownerName: String = "Dock",
        windowName: String = "Wallpaper",
        frame: CGRect,
        isOnscreen: Bool = true
    ) -> [CFString: Any] {
        var window: [CFString: Any] = [
            kCGWindowOwnerName: ownerName,
            kCGWindowName: windowName,
            kCGWindowIsOnscreen: NSNumber(value: isOnscreen),
            kCGWindowBounds: [
                "X": NSNumber(value: Double(frame.origin.x)),
                "Y": NSNumber(value: Double(frame.origin.y)),
                "Width": NSNumber(value: Double(frame.width)),
                "Height": NSNumber(value: Double(frame.height))
            ]
        ]

        if let id {
            window[kCGWindowNumber] = NSNumber(value: id)
        }

        return window
    }
}
