# Plan 003: Harden URL command temp-file cleanup

> **Drift check**: `git diff --stat 2205ed1..HEAD -- Line/Core/URLCommandHandler.swift LineTests/URLCommandHandlerTests.swift`
> Follow plan steps; commit; skip plans/README if reviewer owns it.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: security
- **Planned at**: commit `2205ed1`, 2026-07-22

## Why this matters

`line://list/*` writes keybind names and command lists to
`NSTemporaryDirectory()/line_output_<timestamp>.txt`, opens it, and deletes
only after **60 seconds**. Early quit leaves the file; local processes can
read user config during the window. Legacy plan: `docs/plans/004-temp-file-cleanup.md`.

## Current state

`Line/Core/URLCommandHandler.swift` `flushOutput()` (~256–291):

```swift
let tempFile = FileManager.default.temporaryDirectory
    .appendingPathComponent("line_output_\(timestamp).txt")
try outputBuffer.joined(separator: "\n").write(to: tempFile, atomically: true, encoding: .utf8)
NSWorkspace.shared.open(tempFile)
Task {
    try? await Task.sleep(for: .seconds(60))
    try FileManager.default.removeItem(at: tempFile)
}
```

## Commands

| Purpose | Command | Expected |
|---------|---------|----------|
| Tests | `xcodebuild test -project Line.xcodeproj -scheme Line -destination 'platform=macOS' -only-testing:LineTests/URLCommandHandlerTests CODE_SIGNING_ALLOWED=NO` | pass |
| Build | `make build` | exit 0 |

## Scope

**In scope**:
- `Line/Core/URLCommandHandler.swift`
- `LineTests/URLCommandHandlerTests.swift`
- Optionally small constants / helper for cleanup policy

**Out of scope**:
- Replacing list output with a full in-app UI (nice-to-have; not required)
- Changing URL command semantics

## Git workflow

- Branch: `advisor/003-url-temp-file-cleanup`
- Commit: `fix: tighten URL scheme temp output file cleanup`

## Steps

### Step 1: Policy constants + safer write

1. Extract cleanup delay to a named constant defaulting to **≤5 seconds** (or immediate delete after open if TextEdit still works — prefer short delay like 3–5s so the app can open the file first).
2. After write, set file attributes to owner-only if possible:
   `try? (tempFile as NSURL).setResourceValue(0o600, forKey: .fileProtectionKey)` is wrong for POSIX mode — use:
   ```swift
   try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tempFile.path)
   ```
3. Keep unique names (timestamp or UUID).
4. Prefer `FileManager.default.temporaryDirectory` still, but document owner-only perms.

### Step 2: Cleanup reliability

1. Track pending cleanup URLs in an instance property `private var pendingOutputFiles: [URL] = []`
2. On deinit or add a package-visible `func cleanupPendingOutputFiles()` called from AppDelegate termination if easy — only if AppDelegate is acceptable; otherwise at minimum cancel-safe Task and shorter delay.
3. If adding AppDelegate hook: `Line/App/AppDelegate.swift` becomes in-scope for one call only.

**Minimum acceptable**: delay ≤5s + 0o600 + unit-testable constant.

### Step 3: Tests

Add pure/static tests for:
- cleanup delay constant ≤ 5
- (if helper) permission bits expectation

Do not require actually writing files in CI if flaky; testing constants + that flush path uses them via static policy enum is enough.

Example:

```swift
enum URLCommandOutputFilePolicy {
    static let cleanupDelaySeconds: TimeInterval = 5
    static let posixPermissions: Int = 0o600
}
```

**Verify**: URLCommandHandlerTests pass

## Done criteria

- [ ] No 60-second delay remains for temp cleanup
- [ ] Files written with owner-only permissions when possible
- [ ] Tests cover policy constants
- [ ] `make build` ok
- [ ] Scope respected

## STOP conditions

- List output redesign requires new SwiftUI surface beyond temp file (defer, report)
- setAttributes fails on all platforms in tests

## Maintenance notes

- Prefer eventual in-app list UI to remove disk entirely
