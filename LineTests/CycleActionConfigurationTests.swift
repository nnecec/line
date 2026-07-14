//
//  CycleActionConfigurationTests.swift
//  LineTests
//
//  Created by Codex on 2026-07-10.
//

@testable import Line
import XCTest

final class CycleActionConfigurationTests: XCTestCase {
    func testSelectedItemIDRemainsSelectedAfterMovingSelectedItemDown() {
        let selectedID = UUID()
        let otherID = UUID()
        var items = [
            CycleActionItem(id: selectedID, action: .standard(.proportional(.leftHalf))),
            CycleActionItem(id: otherID, action: .standard(.proportional(.rightHalf)))
        ]
        let selectedIDs: Set<CycleActionItem.ID> = [selectedID]

        CycleActionSelectionPolicy.moveSelectedItem(by: 1, in: &items, selectedIDs: selectedIDs)

        XCTAssertEqual(selectedIDs, [selectedID])
        XCTAssertEqual(items.map(\.id), [otherID, selectedID])
    }

    func testRemoveSelectedRemovesSelectedIDActionNotOldIndexAction() {
        let firstID = UUID()
        let selectedID = UUID()
        let thirdID = UUID()
        let firstAction = WindowAction.standard(.maximize)
        let selectedAction = WindowAction.standard(.proportional(.leftHalf))
        let thirdAction = WindowAction.standard(.proportional(.rightHalf))
        var items = [
            CycleActionItem(id: firstID, action: firstAction),
            CycleActionItem(id: selectedID, action: selectedAction),
            CycleActionItem(id: thirdID, action: thirdAction)
        ]
        var selectedIDs: Set<CycleActionItem.ID> = [selectedID]

        CycleActionSelectionPolicy.moveItems(from: IndexSet(integer: 0), to: 3, in: &items)
        CycleActionSelectionPolicy.removeSelected(from: &items, selectedIDs: &selectedIDs)

        XCTAssertEqual(items.map(\.action), [thirdAction, firstAction])
        XCTAssertFalse(items.map(\.action).contains(selectedAction))
        XCTAssertTrue(selectedIDs.isEmpty)
    }

    func testAddItemSelectsNewItemID() {
        let existingID = UUID()
        var items = [
            CycleActionItem(id: existingID, action: .standard(.maximize))
        ]
        var selectedIDs: Set<CycleActionItem.ID> = [existingID]

        let newID = CycleActionSelectionPolicy.addNoAction(to: &items, selectedIDs: &selectedIDs)

        XCTAssertEqual(selectedIDs, [newID])
        XCTAssertEqual(items.first?.id, newID)
        XCTAssertEqual(items.first?.action, .special(.noAction))
    }

    func testMovingUnselectedRowDoesNotChangeSelectedIDs() {
        let selectedID = UUID()
        let movedID = UUID()
        let otherID = UUID()
        var items = [
            CycleActionItem(id: selectedID, action: .standard(.maximize)),
            CycleActionItem(id: movedID, action: .standard(.proportional(.leftHalf))),
            CycleActionItem(id: otherID, action: .standard(.proportional(.rightHalf)))
        ]
        let selectedIDs: Set<CycleActionItem.ID> = [selectedID]

        CycleActionSelectionPolicy.moveItems(from: IndexSet(integer: 1), to: 3, in: &items)

        XCTAssertEqual(selectedIDs, [selectedID])
        XCTAssertEqual(items.map(\.id), [selectedID, otherID, movedID])
    }
}
