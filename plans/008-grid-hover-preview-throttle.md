# Plan 008: Throttle grid hover preview; skip full AX prepare

> **Drift check**: `git diff --stat 2205ed1..HEAD -- Line/Grid\ Layout/ Line/Core/GridModeCoordinator.swift Line/Window\ Action\ Indicators/`

## Status

- **Priority**: P0
- **Effort**: M
- **Risk**: MED
- **Depends on**: none (007 optional)
- **Category**: perf
- **Planned at**: commit `2205ed1`, 2026-07-22

## Why this matters

Every `mouseMoved` in grid mode fires `previewCallback` → `updateGridPreview` →
full `WindowResizeExecution.prepare` (multiple AX reads). Causes jank on the
product's first-class grid path.

## Current state

`GridMouseObserver` mouseMoved (~40–50): no throttle; always `previewCallback`.

`GridModeCoordinator.updateGridPreview` (~168–184):

```swift
let preparedResize = await WindowResizeExecution.prepare(
    action: BoundWindowAction(action: action, keybind: []),
    window: context.window,
    screen: context.screen,
    bounds: context.geometry.workingBounds,
    padding: .zero,
    initialMousePosition: .zero
)
indicatorService.openAndUpdate(context: ResizeContext(preparedResize: preparedResize))
```

## Commands

| Purpose | Command | Expected |
|---------|---------|----------|
| Tests | grid-related: `GridGeometryTests`, `GridModeCoordinatorTests`, `GridContextTests` | pass |
| Build | `make build` | exit 0 |

## Scope

- `Line/Grid Layout/GridMouseObserver.swift`
- `Line/Core/GridModeCoordinator.swift`
- `Line/Window Management/Window Manipulation/WindowResizeExecution.swift` only if adding `prepareForPreview` that skips resolveState
- Indicator service only if needed for frame-only update
- Tests under `LineTests/Grid*.swift`

**Out of scope**: changing grid commit path (must still full prepare on commit)

## Git workflow

- Branch: `advisor/008-grid-hover-preview-throttle`
- Commit: `perf: throttle grid hover previews and skip full AX prepare`

## Steps

### Step 1: Throttle mouseMoved previews

In `GridMouseObserver` or coordinator:
- Debounce/throttle preview updates to ~16–32ms (one Task cancel pattern like StashManager mouse debounce)
- Still update viewModel hover immediately if cheap; throttle only `previewCallback` if that's the expensive part

### Step 2: Preview without full resolveState

Add path that computes target frame from geometry only:

```swift
// Pseudocode
let action = context.geometry.customAction(for: region)
let request = WindowResizeRequest(
    window: context.window,
    action: action,
    screen: context.screen,
    bounds: context.geometry.workingBounds,
    padding: .zero,
    windowProperties: cachedProperties, // snapshot once at grid open
    record: nil
)
let frame = WindowFrameResolver.calculateFrame(for: request)
// feed indicator with ResizeContext that has that frame cached
```

At grid `open`, snapshot `Window.ResolvedProperties` **once** into `GridContext` if needed; reuse for all hovers.

Ensure **commit** (`handleGridAction`) still uses full `WindowResizeExecution.prepare` / engine apply.

### Step 3: Tests

- Throttle policy constant exists
- Frame calculation for grid region matches geometry tests (existing GridGeometry)
- If extract pure function for preview request building, unit test it

**Verify**: build + grid unit tests

## Done criteria

- [ ] Hover path does not call full `resolveState` / multi AX per move (or only once at open)
- [ ] mouseMoved preview throttled
- [ ] Commit path still correct
- [ ] Tests pass

## STOP conditions

- IndicatorService requires full PreparedResize with side effects that cannot be simplified — report API gap

## Maintenance notes

- Preview vs commit frame parity is the critical review item
