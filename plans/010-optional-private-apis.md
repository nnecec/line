# Plan 010: Load hard-linked private APIs optionally

> **Drift check**: `git diff --stat 2205ed1..HEAD -- Line/Private\ APIs/ Line/Extensions/AXUIElement+Extensions.swift`

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: tech-debt / correctness
- **Planned at**: commit `2205ed1`, 2026-07-22

## Why this matters

`PrivateApis.swift` uses `@_silgen_name` for `GetProcessForPID` and
`_AXUIElementGetWindow`. Missing symbols crash at process load. SkyLight already
uses optional `dlsym`. Align private symbols with safe optional loading.

## Current state

```swift
@_silgen_name("GetProcessForPID")
func GetProcessForPID(...)
@_silgen_name("_AXUIElementGetWindow")
func AXUIElementGetWindow(...)
```

Call sites:
- `SkyLightToolBelt.makeFrontProcess` / `makeKeyWindow` — GetProcessForPID
- `AXUIElement+Extensions` getWindowID — AXUIElementGetWindow

## Commands

| Purpose | Command | Expected |
|---------|---------|----------|
| Build | `make build` | exit 0 |
| Unit | `make test-unit` | pass |

## Scope

- `Line/Private APIs/PrivateApis.swift` — replace or empty out hard links
- `Line/Private APIs/SkyLightSymbolLoader.swift` or new `PrivateSymbolLoader.swift`
- `Line/Private APIs/SkyLightToolBelt.swift`
- `Line/Extensions/AXUIElement+Extensions.swift`
- Tests if any pure fallback behavior testable

**Out of scope**:
- Code signature verification of SkyLight.framework (prior residual; SIP limited value)
- All SkyLight symbols

## Git workflow

- Branch: `advisor/010-optional-private-apis`
- Commit: `fix: resolve private process/window symbols optionally`

## Steps

### Step 1: Dynamic load helpers

Pattern after SkyLightSymbolLoader:

```swift
enum PrivateSymbolLoader {
    private static let handle: UnsafeMutableRawPointer? = {
        // GetProcessForPID lives in ApplicationServices / HIServices — use dlopen(NULL) or appropriate framework
        dlopen(nil, RTLD_LAZY) // or specific path documented in research
    }()
    static let GetProcessForPID: (...)? = loadSymbol("GetProcessForPID")
    static let AXUIElementGetWindow: (...)? = loadSymbol("_AXUIElementGetWindow")
}
```

Research correct image: symbols may resolve via `dlsym(RTLD_DEFAULT, ...)`. Prefer `dlsym(RTLD_DEFAULT, name)` without hard crash.

Remove `@_silgen_name` declarations so missing symbols don't fail link/load.

### Step 2: Call site fallbacks

- GetProcessForPID nil → makeFrontProcess/makeKeyWindow return false (already have guard style)
- AXUIElementGetWindow nil → getWindowID throws or returns error path already used when AX fails

### Step 3: Build and test

Ensure Debug build links. Run unit tests.

**Verify**: `make build` && `make test-unit`

## Done criteria

- [ ] No `@_silgen_name` for these two symbols
- [ ] Optional pointers; nil-safe call sites
- [ ] Build + unit tests pass

## STOP conditions

- Linker still requires symbols / cannot find via dlsym on macOS 26 — document and keep silgen only for the one that works
- Focus breaks with no public fallback — must keep feature working when symbols present

## Maintenance notes

- AGENTS.md: private APIs must handle missing symbols
- Test on macOS 26 before release
