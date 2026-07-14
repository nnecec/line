//
//  GridConfigurationManager.swift
//  Line
//
//  Manages grid templates and memory.
//  Created by nnecec on 2024-12-30.

//

import AppKit
import Defaults
import Foundation

/// Manages grid configuration: templates per screen and size memory per app+screen.
final class GridConfigurationManager {
    static let shared = GridConfigurationManager()
    private init() {}

    // MARK: - Template Management

    /// Get the global default template.
    var defaultTemplate: GridTemplate {
        Defaults[.defaultGridTemplate]
    }

    /// Get the template for a specific screen.
    /// Returns screen override if exists, otherwise returns global default.
    func template(for screen: NSScreen) -> GridTemplate {
        let identifier = screen.gridIdentifier
        return Defaults[.screenGridTemplates][identifier] ?? defaultTemplate
    }

    /// Set a custom template for a specific screen.
    func setTemplate(_ template: GridTemplate, for screen: NSScreen) {
        let identifier = screen.gridIdentifier
        var templates = Defaults[.screenGridTemplates]
        templates[identifier] = template
        Defaults[.screenGridTemplates] = templates
    }

    /// Remove custom template for a screen (revert to global default).
    func removeTemplate(for screen: NSScreen) {
        let identifier = screen.gridIdentifier
        var templates = Defaults[.screenGridTemplates]
        templates.removeValue(forKey: identifier)
        Defaults[.screenGridTemplates] = templates
    }

    /// Check if a screen has a custom template override.
    func hasCustomTemplate(for screen: NSScreen) -> Bool {
        let identifier = screen.gridIdentifier
        return Defaults[.screenGridTemplates][identifier] != nil
    }

    // MARK: - Memory Management

    /// Get remembered size for an app on a screen.
    /// Returns 1x1 if no memory exists or if bundleId is nil.
    /// Automatically clamps to current template size.
    func rememberedSize(bundleId: String?, screen: NSScreen) -> GridSize {
        guard let bundleId, !bundleId.isEmpty else {
            return .default
        }

        let key = GridMemoryKey(bundleId: bundleId, screenIdentifier: screen.gridIdentifier)
        let template = self.template(for: screen)

        guard let stored = Defaults[.gridMemory][key.storageKey] else {
            return .default
        }

        return stored.clamped(to: template)
    }

    /// Save size memory for an app on a screen.
    /// Does nothing if bundleId is nil.
    func saveSize(_ size: GridSize, bundleId: String?, screen: NSScreen) {
        guard let bundleId, !bundleId.isEmpty else {
            return
        }

        let key = GridMemoryKey(bundleId: bundleId, screenIdentifier: screen.gridIdentifier)
        var memory = Defaults[.gridMemory]
        memory[key.storageKey] = size
        Defaults[.gridMemory] = memory
    }

    /// Clear all grid size memory.
    func clearAllMemory() {
        Defaults[.gridMemory] = [:]
    }

    /// Clear memory for a specific app across all screens (useful for testing/debugging).
    func clearMemory(for bundleId: String) {
        var memory = Defaults[.gridMemory]
        memory = memory.filter { key, _ in
            guard let parsed = GridMemoryKey(storageKey: key) else { return true }
            return parsed.bundleId != bundleId
        }
        Defaults[.gridMemory] = memory
    }

    /// Clear memory for a specific screen (useful for testing/debugging).
    func clearMemory(for screen: NSScreen) {
        let identifier = screen.gridIdentifier
        var memory = Defaults[.gridMemory]
        memory = memory.filter { key, _ in
            guard let parsed = GridMemoryKey(storageKey: key) else { return true }
            return parsed.screenIdentifier != identifier
        }
        Defaults[.gridMemory] = memory
    }
}
