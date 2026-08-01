//
//  DirectionPickerSearchPolicy.swift
//  Line
//

/// Pure search policy for the window action picker.
enum DirectionPickerSearchPolicy {
    static func results(
        for query: String,
        in items: [WindowDirection]
    ) -> [WindowDirection] {
        guard !query.isEmpty else { return [] }

        let key = query.lowercased()

        return items.enumerated()
            .compactMap { index, item -> (item: WindowDirection, score: Int, index: Int)? in
                guard let score = fuzzyScore(item.name, key) else { return nil }
                return (item, score, index)
            }
            .sorted { first, second in
                if first.score != second.score {
                    return first.score < second.score
                }

                return first.index < second.index
            }
            .map(\.item)
    }

    private static func fuzzyScore(_ text: String, _ pattern: String) -> Int? {
        let text = text.lowercased()
        let pattern = pattern.lowercased()

        if text.hasPrefix(pattern) {
            return 0
        }

        if text.contains(pattern) {
            return 1
        }

        var textIndex = text.startIndex
        var patternIndex = pattern.startIndex
        while textIndex < text.endIndex, patternIndex < pattern.endIndex {
            if text[textIndex] == pattern[patternIndex] {
                patternIndex = text.index(after: patternIndex)
            }
            textIndex = text.index(after: textIndex)
        }

        return patternIndex == pattern.endIndex ? 2 : nil
    }
}
