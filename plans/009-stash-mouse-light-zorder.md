# Plan 009: Avoid full windowList on every stash mouse tick

> **Drift check**: `git diff --stat 2205ed1..HEAD -- Line/Stashing/ Line/Window\ Management/Window/WindowUtility.swift`
> Prefer landing after 007 so light list exists.

## Status

- **Priority**: P0
- **Effort**: M
- **Risk**: LOW–MED
- **Depends on**: 007 (use lightweight list)
- **Category**: perf
- **Planned at**: commit `2205ed1`, 2026-07-22

## Why this matters

With any stashed windows, mouse moves (~50ms debounce) call
`getZSortedStashedWindows()` → full AX `windowList()`. Constant background cost.

## Current state

```swift
// StashManager
private func getZSortedStashedWindows() -> [StashedWindowInfo] {
    WindowUtility.windowList().compactMap { store.stashed[$0.cgWindowID] }
}
```

Called from `processMouseMovement` every debounced move.

## Commands

| Purpose | Command | Expected |
|---------|---------|----------|
| Build | `make build` | exit 0 |
| Tests | StashOverlapPolicyTests + any new | pass |

## Scope

- `Line/Stashing/StashManager.swift`
- `Line/Window Management/Window/WindowUtility.swift` if 007 not merged yet (implement minimal light list here only as last resort — prefer depend on 007)
- Tests

## Git workflow

- Branch: `advisor/009-stash-mouse-light-zorder`
- Commit: `perf: rank stashed windows without full AX window list`

## Steps

### Step 1: Z-order from lightweight list

```swift
private func getZSortedStashedWindows() -> [StashedWindowInfo] {
    WindowUtility.lightweightWindowList().compactMap { store.stashed[$0.cgWindowID] }
}
```

CG on-screen list order is front-to-back (existing comment assumes this).

If 007 not available, STOP and report — do not reimplement a divergent light list unless 007 is BLOCKED; then implement minimal shared helper.

### Step 2: Optional hit-test short circuit

Before z-order enumeration, if mouse is not near any `stashedFrame`/`revealedFrame` (with tolerance), return early without listing windows. Use store.stashed values only (no AX).

### Step 3: Tests

- Pure function: filter stashed by light ID order
- Overlap policy tests still pass

**Verify**: build

## Done criteria

- [ ] Debounced mouse path does not call `WindowUtility.windowList()`
- [ ] Z-order still prefers frontmost stash under cursor
- [ ] Early-out when cursor far from stash edges (if implemented)

## STOP conditions

- 007 not done and cannot share API
- Z-order regression cannot be validated — keep light list order identical to prior CG order

## Maintenance notes

- Space changes may need cache invalidation if you add caching beyond light list
