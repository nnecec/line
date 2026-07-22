# Plan 005: Prune failed stash restores from Defaults

> **Drift check**: `git diff --stat 2205ed1..HEAD -- Line/Stashing/ LineTests/`

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `2205ed1`, 2026-07-22

## Why this matters

`StashedWindowStore.restore()` keeps un-restorable window IDs in
`Defaults[.stashManagerStashedWindows]` forever. Dead CGWindowIDs accumulate;
restore work and Defaults payload grow without bound for closed apps.

## Current state

`Line/Stashing/StashedWindowStore.swift`:
- `failedToRestore` filled when `getStashedWindow` fails (~100–102)
- Space observer retries (~132–155)
- `setStashedWindow` writes Defaults from **in-memory** `stashed` only (~73)
- Failed entries stay in Defaults until some successful `setStashedWindow` overwrites entire dict without them — but if restore never fully succeeds, Defaults retain ghosts

Also: when **all** restores fail, `stashed` may stay empty and Defaults never rewritten.

## Commands

| Purpose | Command | Expected |
|---------|---------|----------|
| Tests | `xcodebuild test ... -only-testing:LineTests/StashOverlapPolicyTests` plus any new file | pass |
| Build | `make build` | exit 0 |

## Scope

**In scope**:
- `Line/Stashing/StashedWindowStore.swift`
- `Line/Stashing/StashManager.swift` only if needed
- New tests under `LineTests/` (e.g. `StashedWindowStoreTests.swift` or extend existing) — prefer testing pure persistence policy if store is hard to unit-test

**Out of scope**:
- Reveal/hide mouse performance (plan 009)
- Changing stash UX

## Git workflow

- Branch: `advisor/005-prune-failed-stash-defaults`
- Commit: `fix: prune unrestorable stash entries from Defaults`

## Steps

### Step 1: Define prune policy

After restore pass:

1. Persist Defaults as: successfully restored windows' actions + still-pending `failedToRestore` entries that we still hope to recover on space change.
2. **Prune** entries that are known permanently dead:
   - Prefer: if window ID not found after N space changes, drop
   - Or simpler: rewrite Defaults after each restore attempt to `stashed` + `failedToRestore` (so closed windows that reappear later can still restore) BUT remove IDs when app is not running / window list can never include them

**Simplest correct approach** (recommended):

```swift
private func persistStashDefaults() {
    var payload: [CGWindowID: String] = [:]
    for (id, info) in stashed {
        if let value = info.action.action.stashPersistenceValue {
            payload[id] = value
        }
    }
    for (id, action) in failedToRestore {
        if let value = action.stashPersistenceValue {
            payload[id] = value
        }
    }
    Defaults[.stashManagerStashedWindows] = payload
}
```

Call after restore and after space-change recovery.  
Additionally: **drop failed entries** whose owning process no longer exists (check `NSRunningApplication(processIdentifier:)` or CG window list empty for that ID after space observer tried at least once).

Even simpler MVP: after initial restore, set Defaults to only `restoredStashedWindows` keys' actions, and keep `failedToRestore` **in memory only** for the session (space observer still works). That prunes Defaults of ghosts immediately while still recovering same-session space switches.

**Choose MVP**: rewrite Defaults after restore to only successfully restored entries; keep failed in memory for space observer; if space recovers, `setStashedWindow` / persist again. Accept that quit mid-space loses failed-to-restore (acceptable — windows not visible).

### Step 2: Implement

Refactor `setStashedWindow` and restore path to share `persistStashDefaults()` so one write path.

### Step 3: Tests

If store is not easily testable, extract:

```swift
enum StashPersistencePolicy {
    static func defaultsPayload(
        stashed: [CGWindowID: String],
        failedInMemoryOnly: Bool
    ) -> ...
}
```

Or test encoding round-trip still works via existing WindowAction stashPersistenceValue.

At minimum: unit test documenting that payload for restore result excludes failed IDs when using MVP policy.

**Verify**: build + tests

## Done criteria

- [ ] After restore, Defaults does not retain IDs that failed and are only kept in memory (MVP) OR explicitly documents prune rules with tests
- [ ] Space-change restore still works for windows that appear later in-session
- [ ] `make build` ok

## STOP conditions

- Changing Defaults shape breaks migration unexpectedly

## Maintenance notes

- Reviewer: ensure restart still restores stash for windows present at launch
