//
//  GridMemoryPersistence.swift
//  Line
//
//  Persistent app-and-display grid memory boundary.
//

import Defaults

@MainActor
protocol GridMemoryPersisting: AnyObject {
    func size(for key: GridMemoryKey) -> GridSize?
    func save(_ size: GridSize, for key: GridMemoryKey)
    func records() -> [GridMemoryRecord]
    func remove(_ keys: Set<GridMemoryKey>)
    func removeAll()
}

@MainActor
final class DefaultsGridMemoryStore: GridMemoryPersisting {
    typealias RawMemory = [String: GridSize]

    private let read: () -> RawMemory
    private let write: (RawMemory) -> ()

    convenience init() {
        self.init(
            read: { Defaults[.gridMemory] },
            write: { Defaults[.gridMemory] = $0 }
        )
    }

    init(
        read: @escaping () -> RawMemory,
        write: @escaping (RawMemory) -> ()
    ) {
        self.read = read
        self.write = write
    }

    func size(for key: GridMemoryKey) -> GridSize? {
        read()[GridMemoryCodec.storageKey(for: key)]
    }

    func save(_ size: GridSize, for key: GridMemoryKey) {
        var memory = read()
        memory[GridMemoryCodec.storageKey(for: key)] = size
        write(memory)
    }

    func records() -> [GridMemoryRecord] {
        GridMemoryCodec.records(from: read())
    }

    func remove(_ keys: Set<GridMemoryKey>) {
        var memory = read()
        for key in keys {
            memory.removeValue(forKey: GridMemoryCodec.storageKey(for: key))
        }
        write(memory)
    }

    func removeAll() {
        write([:])
    }
}

private enum GridMemoryCodec {
    static func storageKey(for key: GridMemoryKey) -> String {
        "\(key.bundleId)::\(key.screenIdentifier)"
    }

    static func key(from storageKey: String) -> GridMemoryKey? {
        let parts = storageKey.components(separatedBy: "::")
        guard parts.count == 2,
              !parts[0].isEmpty,
              !parts[1].isEmpty
        else {
            return nil
        }
        return GridMemoryKey(bundleId: parts[0], screenIdentifier: parts[1])
    }

    static func records(from memory: DefaultsGridMemoryStore.RawMemory) -> [GridMemoryRecord] {
        memory.compactMap { storageKey, size in
            guard let key = key(from: storageKey) else { return nil }
            return GridMemoryRecord(key: key, size: size)
        }
        .sorted {
            if $0.key.bundleId != $1.key.bundleId {
                return $0.key.bundleId.localizedStandardCompare($1.key.bundleId) == .orderedAscending
            }
            return $0.key.screenIdentifier.localizedStandardCompare($1.key.screenIdentifier) == .orderedAscending
        }
    }
}
