# Plan 006: Drop unsupported loop:// URL scheme

> **Drift check**: `git diff --stat 2205ed1..HEAD -- Line/Core/URLCommandHandler.swift LineTests/URLCommandHandlerTests.swift docs/URL_SCHEME.md`

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: security
- **Planned at**: commit `2205ed1`, 2026-07-22

## Why this matters

Docs and Info.plist only register `line://`. Handler still accepts `loop://`,
creating decision drift and an undocumented acceptance path for Apple Events.

## Current state

```swift
// URLCommandHandler.Scheme
static let legacy = "loop"
static let supported: Set<String> = [canonical, legacy]
```

Tests: `testLegacyLoopSchemeIsStillAccepted` expects true.  
`docs/URL_SCHEME.md`: does not register loop://.

## Commands

| Purpose | Command | Expected |
|---------|---------|----------|
| Tests | `xcodebuild test ... -only-testing:LineTests/URLCommandHandlerTests CODE_SIGNING_ALLOWED=NO` | pass |
| Build | `make build` | exit 0 |

## Scope

- `Line/Core/URLCommandHandler.swift`
- `LineTests/URLCommandHandlerTests.swift`
- `docs/URL_SCHEME.md` only if a sentence needs tightening

## Git workflow

- Branch: `advisor/006-drop-loop-url-scheme`
- Commit: `fix: stop accepting legacy loop:// URL scheme`

## Steps

### Step 1: Remove legacy scheme

```swift
enum Scheme {
    static let canonical = "line"
    static let supported: Set<String> = [canonical]
}
```

Remove `legacy` constant or keep commented that Loop conflict avoidance is intentional.

### Step 2: Update tests

- Rename/replace `testLegacyLoopSchemeIsStillAccepted` → `testLegacyLoopSchemeIsRejected` asserting `supports` is false for `loop://direction/right`
- Keep line:// tests green

### Step 3: Docs

Ensure `docs/URL_SCHEME.md` still says Line does not register loop://. Add one line: handler also rejects loop://.

**Verify**: tests + build

## Done criteria

- [ ] `URLCommandHandler.supports(loop://...)` is false
- [ ] Tests updated and pass
- [ ] Docs consistent

## STOP conditions

- Product decision to keep loop for migration (then report instead of removing)

## Maintenance notes

- Do not re-add loop without registering Info.plist + SECURITY review
