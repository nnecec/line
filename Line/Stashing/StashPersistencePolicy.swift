//
//  StashPersistencePolicy.swift
//  Line
//
//  Pure policy for what stash state is written to Defaults.
//

import CoreGraphics
import Foundation

enum StashPersistencePolicy {
    /// Builds the Defaults payload from successfully stashed windows only.
    /// Failed-to-restore IDs are intentionally omitted so dead CGWindowIDs
    /// do not accumulate across launches; they remain in-memory for space retries.
    static func defaultsPayload(
        stashedPersistenceValues: [CGWindowID: String]
    ) -> [CGWindowID: String] {
        stashedPersistenceValues
    }
}
