//
//  Defaults+Extensions.swift
//  Line
//
//  Created by nnecec on 2023-06-14.
//
// Line ships without the iCloud key-value-store entitlement. Keys intentionally use Defaults'
// local UserDefaults storage; omitting the iCloud flag preserves existing key names and values.

import Defaults
import SwiftUI

// MARK: - UI-configurable Settings

extension Defaults.Keys {
    // App icon customization and Dock presentation
    static let currentIcon = Key<String>("currentIcon", default: "AppIcon-Classic")
    static let showDockIcon = Key<Bool>("showDockIcon", default: false)
}

// MARK: - Keybinds Configuration

extension Defaults.Keys {
    // Accent Color
    static let accentColorMode: Key<AccentColorOption> = Key("accentColorMode", default: .system)
    static let customAccentColor = Key<Color>("customAccentColor", default: .teal)
    static let useGradient = Key<Bool>("useGradient", default: false)
    static let gradientColor = Key<Color>("gradientColor", default: .blue)

    // Preview
    static let previewVisibility = Key<Bool>("previewVisibility", default: true)
    static let previewPadding = Key<CGFloat>("previewPadding", default: 10)
    static let previewCornerRadius = Key<CGFloat>("previewCornerRadius", default: 10)
    static let previewBorderThickness = Key<CGFloat>("previewBorderThickness", default: 1.5)
    static let previewUseWindowCornerRadius = Key<Bool>("previewUseWindowCornerRadius", default: true)
    static let previewBackgroundEnableBlur = Key<Bool>("previewBackgroundEnableBlur", default: true)
    static let previewBackgroundAccentOpacity = Key<CGFloat>("previewBackgroundAccentOpacity", default: 0.12)

    // Behavior
    static let launchAtLogin = Key<Bool>("launchAtLogin", default: false)
    static let startHidden = Key<Bool>("startHidden", default: false)
    static let hideMenuBarIcon = Key<Bool>("hideMenuBarIcon", default: false)
    static let animationConfiguration = Key<AnimationConfiguration>("animationConfiguration", default: .snappy)
    static let windowSnapping = Key<Bool>("windowSnapping", default: false)
    static let suppressMissionControlOnTopDrag = Key<Bool>("suppressMissionControlOnTopDrag", default: true)
    static let restoreWindowFrameOnDrag = Key<Bool>("restoreWindowFrameOnDrag", default: false)
    static let enablePadding = Key<Bool>("enablePadding", default: false)
    static let padding = Key<PaddingConfiguration>("padding", default: .zero)
    static let useScreenWithCursor = Key<Bool>("useScreenWithCursor", default: true)
    static let moveCursorWithWindow = Key<Bool>("moveCursorWithWindow", default: false)
    static let resizeWindowUnderCursor = Key<Bool>("resizeWindowUnderCursor", default: false)
    static let focusWindowOnResize = Key<Bool>("focusWindowOnResize", default: true)
    static let respectStageManager = Key<Bool>("respectStageManager", default: true)
    static let stageStripSize = Key<CGFloat>("stageStripSize", default: 150)
    static let animateStashedWindows = Key<Bool>("animateStashedWindows", default: true)
    static let stashedWindowVisiblePadding = Key<CGFloat>("stashedWindowVisiblePadding", default: 20)
    static let shiftFocusWhenStashed = Key<Bool>("shiftFocusWhenStashed", default: true)
    static let cycleModeRestartEnabled = Key<Bool>("cycleModeRestartEnabled", default: false)
}

// MARK: - Keybinds Configuration (continued)

extension Defaults.Keys {
    // Keybinds
    static let triggerKey = Key<Set<CGKeyCode>>("trigger", default: [.kVK_Function])
    static let sideDependentTriggerKey = Key<Bool>("sideDependentTriggerKey", default: true)
    static let triggerDelay = Key<Double>("triggerDelay", default: 0)
    static let doubleClickToTrigger = Key<Bool>("doubleClickToTrigger", default: false)
    static let middleClickTriggersLine = Key<Bool>("middleClickTriggersLine", default: false)
    static let enableTriggerDelayOnMiddleClick = Key<Bool>("enableTriggerDelayOnMiddleClick", default: false)
    static let cycleBackwardsOnShiftPressed = Key<Bool>("cycleBackwardsOnShiftPressed", default: true)
    // NOTE: keybinds is defined in Defaults+WindowAction.swift
}

// MARK: - Advanced Settings

extension Defaults.Keys {
    // Advanced
    static let useSystemWindowManagerWhenAvailable = Key<Bool>("useSystemWindowManagerWhenAvailable", default: false)
    static let animateWindowResizes = Key<Bool>("animateWindowResizes", default: false)
    static let ignoreFullscreen = Key<Bool>("ignoreFullscreen", default: false)
    static let hideOnNoSelection = Key<Bool>("hideOnNoSelection", default: false)
    static let hapticFeedback = Defaults.Key<Bool>("hapticFeedback", default: true)
    static let sizeIncrement = Key<CGFloat>("sizeIncrement", default: 20)

    /// Excluded apps
    static let excludedApps = Key<[URL]>("excludedApps", default: [])

    /// Grid Layout
    static let defaultGridTemplate = Key<GridTemplate>(
        "defaultGridTemplate",
        default: GridTemplate.default
    )
    static let screenGridTemplates = Key<[String: GridTemplate]>(
        "screenGridTemplates",
        default: [:]
    )
    static let gridMemory = Key<[String: GridSize]>(
        "gridMemory",
        default: [:]
    )
    static let gridFollowsAppAccentColor = Key<Bool>(
        "gridFollowsAppAccentColor",
        default: true
    )
    static let gridOverlayAccentColor = Key<Color>(
        "gridOverlayAccentColor",
        default: .accentColor
    )
    static let gridOverlayOpacity = Key<Double>(
        "gridOverlayOpacity",
        default: 0.3
    )
    static let gridLineThickness = Key<CGFloat>(
        "gridLineThickness",
        default: 1
    )
    static let gridCellCornerRadius = Key<CGFloat>(
        "gridCellCornerRadius",
        default: 4
    )
    static let gridOverlayBlurEnabled = Key<Bool>(
        "gridOverlayBlurEnabled",
        default: true
    )
}

// MARK: - Hidden Settings

extension Defaults.Keys {
    /// Minimum screen size, defined in inches on the diagonal, for which padding will be applied on windows.
    /// Adjust with `defaults write com.nnecec.Line paddingMinimumScreenSize -float x`
    /// Reset with `defaults delete com.nnecec.Line paddingMinimumScreenSize`
    static let paddingMinimumScreenSize = Key<CGFloat>("paddingMinimumScreenSize", default: 0)

    /// Ignore the notch height when calculating top padding, so the effective
    /// distance from the screen top matches non-notch displays.
    /// Adjust with `defaults write com.nnecec.Line ignoreNotch -bool true`
    /// Reset with `defaults delete com.nnecec.Line ignoreNotch`
    static let ignoreNotch = Key<Bool>("ignoreNotch", default: false)

    /// Snap threshold for window snapping, defined in points.
    /// Adjust with `defaults write com.nnecec.Line snapThreshold -float x`
    /// Reset with `defaults delete com.nnecec.Line snapThreshold`
    static let snapThreshold = Key<CGFloat>("snapThreshold", default: 2)

    /// Whether to ignore low power mode for certain features, such as window animations.
    /// Adjust with `defaults write com.nnecec.Line ignoreLowPowerMode -bool x`
    /// Reset with `defaults delete com.nnecec.Line ignoreLowPowerMode`
    static let ignoreLowPowerMode = Key<Bool>("ignoreLowPowerMode", default: false)

    /// Adjust with `defaults write com.nnecec.Line previewStartingPosition [option]`
    /// Reset with `defaults delete com.nnecec.Line previewStartingPosition`
    ///
    /// Available options:
    /// - `screenCenter`: Center of the screen
    /// - `actionCenter`: Center of the selected action (e.g. for left half, it will grow from the center of that left half)
    static let previewStartingPosition = Key<PreviewStartingPosition>("previewStartingPosition", default: .actionCenter)

    /// Trigger key timeout, defined in seconds. Automatically closes Line if no action is taken within the specified time.
    /// When set to 0 (default: disabled), the feature is disabled and Line stays open until manually closed.
    /// Adjust with `defaults write com.nnecec.Line triggerKeyTimeout -float x`
    /// Reset with `defaults delete com.nnecec.Line triggerKeyTimeout`
    static let triggerKeyTimeout = Key<Double>("triggerKeyTimeout", default: 0)

    // Migrator

    static let lastMigratorURL = Key<URL?>("lastMigratorURL", default: nil)

    // StashManager
    // Stores only WindowAction (not full BoundWindowAction) because keybinds are irrelevant
    // to persisted window stash state. The stash edge and name are what matter for restoration.
    static let stashManagerStashedWindows = Key<[CGWindowID: String]>("stashManagerStashed", default: [:])

    // AccentColorController

    static let lastUsedAccentColor1 = Key<Color>("lastUsedAccentColor1", default: .black)
    static let lastUsedAccentColor2 = Key<Color>("lastUsedAccentColor2", default: .black)

    // DataPatcher

    static let patchesApplied = Key<DataPatcher.Patches>("patchesApplied", default: [])
}
