# Plan 002: Wire stash revealed frame into session open

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on.
> Touch only in-scope files. STOP conditions: stop and report — do not improvise.
> Commit in the worktree. SKIP updating `plans/README.md` if a reviewer maintains the index.
>
> **Drift check**: `git diff --stat 2205ed1..HEAD -- Line/Core/LineCoordinator.swift Line/Core/SessionManager.swift Line/Core/GridModeCoordinator.swift Line/Window\ Management/Window\ Manipulation/WindowResizeExecution.swift Line/Window\ Management/Window\ Action/WindowResizeRequest.swift LineTests/SessionManagerTests.swift`

## Status

- **Priority**: P0
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `2205ed1`, 2026-07-22

## Why this matters

When a window is stashed, its AX frame is the edge-hidden rect. Opening Line /
grid mode must use the **revealed** frame for layout math (comment already says
so). Today three call sites compute that frame and **discard** it (`_ =` or
unused `let`). Subsequent maximize/half/grid math runs on the stashed rect →
wrong target frames.

## Current state

`Line/Core/LineCoordinator.swift` (~305–323) computes `initialWindowFrame` then
calls `sessionManager.open` without passing it:

```swift
let initialWindowFrame = await {
    await StashManager.shared.getRevealedFrameForStashedWindow(
        id: window.cgWindowID
    ) ?? window.frame
}()
// ... never used ...
await sessionManager.open(window: window, initialMousePosition: ..., startingAction: ...)
```

`Line/Core/SessionManager.swift` (~79–93):

```swift
_ = if let window {
    await StashManager.shared.getRevealedFrameForStashedWindow(...) ?? window.frame
} else {
    CGRect.zero
}
let preparedResize = await WindowResizeExecution.prepare(
    action: ...,
    window: window,
    initialMousePosition: initialMousePosition
)
```

Same discard pattern in `GridModeCoordinator.open` (~64–79).

`WindowResizeRequest` already has `windowProperties: WindowProperties?` with
`frame` + `isResizable`. `WindowResizeExecution.prepare` accepts optional
`window` and builds `WindowProperties(window:)` when nil is not provided via
resolved state — see `resolveState` using `Window.ResolvedProperties(from:)`.

`WindowProperties` is defined near window action types — open with:

```bash
rg -n "struct WindowProperties" Line --type swift
```

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Unit tests | `xcodebuild test -project Line.xcodeproj -scheme Line -destination 'platform=macOS' -skip-testing:LineTests/EndToEndIntegrationTests -only-testing:LineTests/SessionManagerTests CODE_SIGNING_ALLOWED=NO` | pass |
| Broader unit | `make test-unit` | pass (if time; at least SessionManager + any new tests) |
| Debug build | `make build` | exit 0 |

## Conventions

- Main actor for coordinator/session code
- Prefer pure helpers / optional params over new manager types
- Tests: model after `LineTests/SessionManagerTests.swift` and policy tests like `LineCoordinatorPolicyTests.swift`
- Logging: never log window titles; use `ApplicationLogPrivacy`

## Scope

**In scope**:
- `Line/Core/SessionManager.swift`
- `Line/Core/LineCoordinator.swift`
- `Line/Core/GridModeCoordinator.swift`
- `Line/Window Management/Window Manipulation/WindowResizeExecution.swift` (only if needed to accept override frame)
- `Line/Window Management/Window Action/WindowResizeRequest.swift` / `WindowProperties` only if needed
- `LineTests/SessionManagerTests.swift` and/or new small policy unit test file
- Optionally extract a tiny pure helper e.g. `StashFramePolicy` in Stashing or Core for testability

**Out of scope**:
- Stash reveal/hide animation
- WindowEngine / full AX rewrite
- PERF plans 007–009

## Git workflow

- Branch: `advisor/002-wire-stash-revealed-frame`
- Commit: `fix: use stash revealed frame when opening window sessions`
- Do NOT push

## Steps

### Step 1: Design the override path

Add a clear way to pass an override frame into prepare:

**Preferred approach** (minimal surface):

1. Add optional parameter to `SessionManager.open`:
   `windowFrameOverride: CGRect? = nil`
2. When non-nil, build `WindowProperties(frame: override, isResizable: window.map { $0.isResizable } ?? true)` (use existing WindowProperties initializer pattern from codebase) and pass into `WindowResizeExecution.prepare` via a new optional `windowProperties:` argument if not present, OR set on prepared path.

If `WindowResizeExecution.prepare` only takes `window` and always re-reads frame from AX, extend:

```swift
static func prepare(
    ...
    window: Window?,
    windowProperties: WindowProperties? = nil,  // if already exists use it
    ...
)
```

Check `prepare` / `resolveState` — when `windowProperties` override is provided, **do not** replace `frame` with live AX frame.

For `GridModeCoordinator.open`, same: resolve revealed frame and pass into prepare as properties override.

For `LineCoordinator`: either
- pass override into `sessionManager.open(windowFrameOverride:)`, and
- for grid path ensure `gridModeCoordinator.open` does the same internally (remove dead local discard)

Remove unused `initialWindowFrame` in LineCoordinator if session path no longer needs it at coordinator level — prefer computing inside SessionManager/GridModeCoordinator only once to avoid duplication.

**Verify**: code compiles conceptually; no discarded revealed-frame values remain at the three sites.

### Step 2: Implement wiring

1. SessionManager: use override / revealed frame when building prepare
2. GridModeCoordinator: same
3. LineCoordinator: delete dead `initialWindowFrame` if fully handled in children; ensure grid path still correct
4. If window is not stashed, behavior must equal current (use live frame)

**Verify**: `make build` exit 0

### Step 3: Unit tests

Add tests that do **not** require Accessibility when possible:

- Pure helper: `effectiveWindowFrame(revealed: CGRect?, live: CGRect) -> CGRect` returns revealed when non-nil else live
- Or: with a mock-free path — if SessionManager always calls StashManager.shared, extract:

```swift
enum StashSessionFramePolicy {
    static func frameForLayout(revealedFrame: CGRect?, currentFrame: CGRect) -> CGRect {
        revealedFrame ?? currentFrame
    }
}
```

Test that policy; document that SessionManager must use it for WindowProperties.frame.

Also test that when override is passed into prepareResolved with a fake WindowProperties frame, `request.windowProperties?.frame` equals override (if testable without NSScreen issues — use existing ResizeContextTests / WindowResizeExecution patterns).

**Verify**: targeted xcodebuild test for new cases passes

## Test plan

- Policy: revealed non-nil wins; nil falls back to current
- Regression: open session without stash still initializes resizeContext (existing SessionManagerTests)
- If you can call prepareResolved with explicit windowProperties, assert frame preserved

## Done criteria

- [ ] No discarded `getRevealedFrameForStashedWindow` results at SessionManager / GridModeCoordinator / LineCoordinator open paths
- [ ] When revealed frame exists, `WindowResizeExecution` request uses that frame in `windowProperties`
- [ ] Unit tests for the policy / override pass
- [ ] `make build` succeeds
- [ ] Only in-scope files changed

## STOP conditions

- WindowProperties cannot be constructed without full Window / AX
- prepare always overwrites provided properties with live AX and cannot be changed without large refactor
- Drift in SessionManager open signature from other concurrent work

## Maintenance notes

- Any new open path for sessions must call the same policy
- Reviewers: confirm fill/maximize from a stashed window uses full revealed size
