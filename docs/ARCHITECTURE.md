# Architecture

Line is a menu bar macOS application built with SwiftUI and AppKit. It uses the Accessibility API to inspect and move windows, and it loads selected SkyLight symbols at runtime for optional behavior that public APIs do not provide.

## Application lifecycle

`LineApp` defines the SwiftUI scenes and menu bar commands. `AppDelegate` owns AppKit lifecycle work, permission setup, logging policy, migration, and update startup. UI and window-management coordinators run on the main actor.

`LineCoordinator` is the top-level window-management coordinator. It delegates to:

- `TriggerCoordinator` for keyboard and middle-click triggers (see `KeybindTriggerDecision` and `KeybindBindingPolicy` in the Decision and policy modules section)
- `GridModeCoordinator` for grid selection and overlays
- `SessionManager` for the active window action session (including change-action side effects: indicators, apply, timeout restart, haptic, cycle continuation)

The coordinator owns orchestration state. `WindowDragManager` monitors drag events and executes ordered effects from `DragSnapSession`; the session owns the lifecycle of one drag while `DragSnapPolicy` owns geometry decisions. `StashManager` executes Accessibility and store updates based on `StashAftermathDecision`. Geometry and action rules belong in testable calculation or policy types (see Decision and policy modules section).

## Decision and policy modules

Line separates pure decision logic from execution and orchestration. Decision and policy modules are static enums (never instantiated) that take inputs and return outcomes, with no side effects, no Accessibility calls, and no mutable state. This pattern makes core logic testable without window manager permissions and clarifies responsibility boundaries.

Examples:

- `KeybindTriggerDecision` — decides whether a keybind event should open the trigger, close it, or be consumed by the active session
- `KeybindBindingPolicy` — computes effective keybinds (trigger ∪ action or bypass mode) and detects conflicts across all bound actions
- `DragSnapPolicy` — determines snap edge zones and whether a drag-direction change should apply immediately
- `DragSnapSession` — owns per-drag resolution/tracking state and emits ordered effects for the manager to execute
- `StashRevealTransition` — owns the single revealed-window invariant, throttling, and token-checked async transition lifecycle
- `DefaultsGridMemoryStore` — owns persistent grid-memory encoding and Defaults access; coordinators and settings consume typed records
- `URLCommandTargetOrchestrator` — owns URL target selection, activation/screen effects, execution results, and successful sticky-target updates
- `URLTargetWindowPolicy` — selects the target window for `line://` automation (user-defined > sticky window within TTL > first candidate)
- `StashAftermathDecision` — decides stash aftermath after a window resize (stash, unstash, reprocess, ignore, unmanage, etc.)

When to extract a policy or decision module:

- The logic is pure (deterministic output from inputs, no side effects)
- It's called from multiple coordinators or UI components
- Tests need to verify the decision without spinning up the full window manager

Keep the logic in the calling coordinator when it's tightly coupled to that coordinator's lifecycle or rarely reused elsewhere.

## Window actions

`WindowAction` represents standard, custom, cycle, screen-switch, and stash behavior. `BoundWindowAction` connects an action to a configured trigger. Window Resize Execution bootstraps a Prepared Resize for a Window Action Session (or grid), transitions mid-session without re-reading live window state, and commits either the current snapshot (release / grid confirm) or a live re-prepare that inherits the session layout snapshot. `WindowActionEngine` and `WindowEngine` apply Prepared Resize directly through Accessibility APIs. Drag still uses a mutable `ResizeContext` adapter that converts into Prepared Resize at the execution seam.

URL scheme automation (`line://`) is handled by `URLCommandHandler`, which delegates parsing, direction aliases, target-window selection (see `URLTargetWindowPolicy` in Decision and policy modules), and list catalog building to pure modules (`URLCommandParser`, `URLDirectionResolver`, `URLCommandCatalog`).

Grid overlays and window previews are auxiliary panels. They must not become the user's active work window or change focus unless the interaction requires it.

## Settings and persistence

Settings keys live in `Line/Extensions/Defaults+Extensions.swift` and related extensions. SwiftUI reads them through the Defaults property wrappers. Current builds do not ship an iCloud entitlement, so settings must be treated as local even where upstream-compatible key metadata still mentions iCloud.

Grid size memory has two layers. `GridConfigurationManager` persists the latest grid size for an application bundle identifier and display, which acts as the fallback for future windows. It also keeps a bounded, process-local override keyed by process identifier, `CGWindowID`, and display so separate windows from the same application can retain different grid sizes during the current Line session. Window identifiers are never persisted; session overrides are removed when the owning application terminates and cleared when Accessibility access is revoked or Line shuts down. Lookup order is window-and-display override, application-and-display fallback, then the default 1 × 1 grid.

Migrations in `Line/Migration` run during application startup. A migration should be idempotent and covered by characterization tests before old storage is removed.

## Updates

Sparkle is the only supported updater. `SparkleUpdater` wraps the framework for application lifecycle and SwiftUI state. The app reads a signed appcast from GitHub (`appcast.xml` on `main`) and accepts zip archives signed by the EdDSA public key in `Line/Config.xcconfig`. GitHub Releases hold `Line-X.Y.Z` packages; the feed is updated through a post-publish pull request so in-app updates lag the Release until that PR merges.

The application is not sandboxed. Do not enable Sparkle's installer launcher service unless App Sandbox is introduced together with the required XPC service and entitlements.

## Private APIs

Code under `Line/Private APIs` dynamically resolves SkyLight functions. These calls can change between macOS releases. Callers must check symbol availability, keep a public-API fallback where possible, and avoid treating private API behavior as a security boundary.

Changes in this area need testing on every supported macOS release and should record the affected symbols in the pull request.

## Dependencies

Swift Package Manager resolves exact versions or revisions in `Package.resolved`. Defaults provides settings persistence, Scribe provides logging, and Sparkle handles updates. See [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) for license information.
