//
//  StashPersistencePolicyTests.swift
//  LineTests
//

@testable import Line
import XCTest

final class StashPersistencePolicyTests: XCTestCase {
    func testDefaultsPayloadIncludesOnlySuccessfullyStashedEntries() {
        let restored: [CGWindowID: String] = [
            10: #"{"edge":"left"}"#,
            20: #"{"edge":"right"}"#
        ]

        let payload = StashPersistencePolicy.defaultsPayload(
            stashedPersistenceValues: restored
        )

        XCTAssertEqual(payload.count, 2)
        XCTAssertEqual(payload[10], #"{"edge":"left"}"#)
        XCTAssertEqual(payload[20], #"{"edge":"right"}"#)
    }

    func testDefaultsPayloadIsEmptyWhenNothingRestored() {
        let payload = StashPersistencePolicy.defaultsPayload(
            stashedPersistenceValues: [:]
        )

        XCTAssertTrue(payload.isEmpty)
    }
}
