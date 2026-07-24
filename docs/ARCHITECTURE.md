# Architecture

Line is a menu bar macOS application built with SwiftUI and AppKit. It uses the Accessibility API to inspect and move windows, and it loads selected SkyLight symbols at runtime for optional behavior that public APIs do not provide.

## Application lifecycle

`LineApp` defines the SwiftUI scenes and menu bar commands. `AppDelegate` owns AppKit lifecycle work, permission setup, logging policy, migration, and update startup. UI and window-management coordinators run on the main actor.

`LineCoordinator` is the top-level window-management coordinator. It delegates to:

- `TriggerCoordinator` for keyboard and middle-click triggers
- `GridModeCoordinator` for grid selection and overlays
- `SessionManager` for the active window action session

The coordinator owns orchestration state. Geometry and action rules belong in testable calculation or policy types.

## Window actions

`WindowAction` represents standard, custom, cycle, screen-switch, and stash behavior. `BoundWindowAction` connects an action to a configured trigger. Window Resize Execution bootstraps a Prepared Resize for a Window Action Session (or grid), transitions mid-session without re-reading live window state, and commits either the current snapshot (release / grid confirm) or a live re-prepare that inherits the session layout snapshot. `WindowEngine` applies the result through Accessibility APIs. Drag still uses a mutable `ResizeContext` adapter.

Grid overlays and window previews are auxiliary panels. They must not become the user's active work window or change focus unless the interaction requires it.

## Settings and persistence

Settings keys live in `Line/Extensions/Defaults+Extensions.swift` and related extensions. SwiftUI reads them through the Defaults property wrappers. Current builds do not ship an iCloud entitlement, so settings must be treated as local even where upstream-compatible key metadata still mentions iCloud.

Migrations in `Line/Migration` run during application startup. A migration should be idempotent and covered by characterization tests before old storage is removed.

## Updates

Sparkle is the only supported updater. `SparkleUpdater` wraps the framework for application lifecycle and SwiftUI state. The app reads a signed appcast from GitHub (`appcast.xml` on `main`) and accepts zip archives signed by the EdDSA public key in `Line/Config.xcconfig`. GitHub Releases hold `Line-X.Y.Z` packages; the feed is updated through a post-publish pull request so in-app updates lag the Release until that PR merges.

The application is not sandboxed. Do not enable Sparkle's installer launcher service unless App Sandbox is introduced together with the required XPC service and entitlements.

## Private APIs

Code under `Line/Private APIs` dynamically resolves SkyLight functions. These calls can change between macOS releases. Callers must check symbol availability, keep a public-API fallback where possible, and avoid treating private API behavior as a security boundary.

Changes in this area need testing on every supported macOS release and should record the affected symbols in the pull request.

## Dependencies

Swift Package Manager resolves exact versions or revisions in `Package.resolved`. Defaults provides settings persistence, Luminare provides settings components, Scribe provides logging, and Sparkle handles updates. See [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) for license information.
