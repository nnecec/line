# Plan 007: Add lightweight window list for hot paths

> **Drift check**: `git diff --stat 2205ed1..HEAD -- Line/Window\ Management/Window/WindowUtility.swift Line/Window\ Management/Window\ Action/ LineTests/`

## Status

- **Priority**: P0
- **Effort**: M
- **Risk**: MED
- **Depends on**: none (009 depends on this)
- **Category**: perf
- **Planned at**: commit `2205ed1`, 2026-07-22

## Why this matters

`WindowUtility.windowList()` builds full `Window` (AX) for every on-screen CG
window. Hot paths (stash z-order, fill-available, URL targeting) only need IDs
and frames. Tests already inject `visibleWindowFrames` into calculators.

## Current state

```swift
// WindowUtility.windowList()
for windowInfo in list {
    if let window = try? Window.fromWindowInfo(windowInfo) {
        windowList.append(window)
    }
}
```

`Window.fromWindowInfo` does AXUIElementCreateApplication + .windows + frame match.

`WindowResizeRequest.visibleWindowFrames` already supports light geometry for fill-available.

## Commands

| Purpose | Command | Expected |
|---------|---------|----------|
| Unit tests | `make test-unit` | pass |
| Build | `make build` | exit 0 |

## Scope

**In scope**:
- `Line/Window Management/Window/WindowUtility.swift`
- Call sites that only need frames/IDs (switch carefully):
  - fill-available path in calculator/engine if it calls windowList only for frames
  - prepare for plan 009 (export API even if 009 lands later)
- `LineTests/` for filter parity where possible
- Possibly small struct in same file:

```swift
struct LightweightWindowInfo: Equatable {
    let cgWindowID: CGWindowID
    let frame: CGRect
    let ownerPID: pid_t
    let layer: CGWindowLevel
}
```

**Out of scope**:
- Rewriting focus navigation to never use full Window
- Grid hover (008) unless trivial

## Git workflow

- Branch: `advisor/007-lightweight-window-list`
- Commit: `perf: add lightweight CG window list without full AX`

## Steps

### Step 1: Implement `lightweightWindowList()`

Mirror filters from `fromWindowInfo` that can be done from CGWindowInfo alone:
- alpha > 0.01
- layer in [kCGNormalWindowLevel, kCGDraggingWindowLevel] (same as fromWindowInfo)
- extract bounds from kCGWindowBounds
- extract kCGWindowNumber, kCGWindowOwnerPID

Do **not** call AX in this path.

```swift
static func lightweightWindowList() -> [LightweightWindowInfo]
```

Keep existing `windowList()` for callers that need Window.

### Step 2: Switch frame-only callers

Find with:

```bash
rg -n "windowList\(\)" Line --type swift
```

Switch callers that only use `.frame` or map by id for geometry:
- Calculator fill-available default when `visibleWindowFrames == nil` — set frames from lightweight list
- Stash z-order can wait for 009 but if easy, map IDs from light list order (CG list is z-ordered) against stash store keys without full Window

Document which call sites still need full list.

### Step 3: Tests

- Pure test: given synthetic dictionaries… if hard, test that lightweight list returns without crashing and respects empty list
- Prefer unit test of a pure filter function:

```swift
static func lightweightInfo(from windowInfo: [String: AnyObject]) -> LightweightWindowInfo?
```

Test with crafted dicts (alpha 0 filtered, valid bounds parsed).

**Verify**: `make test-unit` / targeted tests + `make build`

## Done criteria

- [ ] `lightweightWindowList` (or equivalent) exists and avoids AX
- [ ] At least one production hot path uses it for frames (fill-available or documented export for 009)
- [ ] Filter unit tests pass
- [ ] Full `windowList()` still works for focus/manipulation paths

## STOP conditions

- CG bounds coordinate space mismatches AX frames for fill-available (document and use conversion; if unknown, only ship API + stash z-order by ID order from CG list without frame compare)

## Maintenance notes

- New enumeration features should default to light list unless AX required
