//
//  LatestTaskRegistry.swift
//  Line
//

import Foundation

/// Tracks the latest asynchronous operation for each key.
///
/// Replacing an operation cancels the previous one. Completion is token based so a
/// late completion from an older operation cannot remove the newer operation.
@MainActor
final class LatestTaskRegistry<Key: Hashable, Output> {
    struct Handle {
        fileprivate let id: UUID
        let task: Task<Output, any Error>
    }

    private struct Entry {
        let id: UUID
        let task: Task<Output, any Error>
    }

    private var entries: [Key: Entry] = [:]

    var activeCount: Int { entries.count }

    func replace(
        for key: Key,
        operation: @escaping @MainActor () async throws -> Output
    ) -> Handle {
        entries[key]?.task.cancel()

        let id = UUID()
        let task = Task {
            try await operation()
        }
        entries[key] = Entry(id: id, task: task)
        return Handle(id: id, task: task)
    }

    func remove(_ handle: Handle, for key: Key) {
        guard entries[key]?.id == handle.id else { return }
        entries.removeValue(forKey: key)
    }
}
