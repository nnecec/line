# Plan 011: Cache SPM/DerivedData/Mint in CI

> **Drift check**: `git diff --stat 2205ed1..HEAD -- .github/workflows/ci.yml .github/workflows/lint.yml`

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW–MED
- **Depends on**: none
- **Category**: dx
- **Planned at**: commit `2205ed1`, 2026-07-22

## Why this matters

CI cold-resolves SPM and reinstalls mint/swiftformat every run. macOS runners
are slow; timeouts are 45 minutes. Only publish.yml caches npm.

## Current state

`.github/workflows/ci.yml`: no actions/cache  
`.github/workflows/lint.yml`: brew install mint every time

## Commands

| Purpose | Command | Expected |
|---------|---------|----------|
| YAML sanity | `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"` or actionlint if available | no parse error |
| rg | `rg -n "actions/cache|cache:" .github/workflows/ci.yml lint.yml` | cache steps present |

## Scope

- `.github/workflows/ci.yml`
- `.github/workflows/lint.yml`

**Out of scope**:
- Changing test matrix
- publish.yml signing (plan 004)

## Git workflow

- Branch: `advisor/011-ci-build-cache`
- Commit: `ci: cache SPM, DerivedData, and Mint for faster CI`

## Steps

### Step 1: CI SPM / DerivedData cache

After checkout + Xcode select, before resolve:

```yaml
- name: Cache SPM and DerivedData
  uses: actions/cache@... # pin a recent hash like other actions in repo
  with:
    path: |
      ~/Library/Developer/Xcode/DerivedData
      Line.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
      # and/or SourcePackages if project uses local path — check where resolve stores
    key: ${{ runner.os }}-xcode-${{ hashFiles('Line.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved', 'Line.xcodeproj/project.pbxproj') }}
    restore-keys: |
      ${{ runner.os }}-xcode-
```

Match pin style of existing `actions/checkout@9c091bb...` in the same file.

If DerivedData cache causes flaky builds, cache only SwiftPM checkouts:
`~/Library/Caches/org.swift.swiftpm` and workspace SourcePackages if present under `dist/` — **do not** cache `dist/` from developer machines; use runner paths only.

### Step 2: Lint Mint cache

Cache `~/.mint` or mint install path keyed by `Mintfile` hash.

### Step 3: Document

Brief comment in workflow why keys include Package.resolved.

**Verify**: YAML valid; cache keys reference Package.resolved

## Done criteria

- [ ] ci.yml has cache step before heavy build/test
- [ ] lint.yml caches mint/swiftformat tooling
- [ ] Keys include Package.resolved or Mintfile
- [ ] No secrets in workflow changes

## STOP conditions

- Cache paths wrong for Xcode 26 on macos-26 runner and cannot verify — use conservative SPM-only cache

## Maintenance notes

- If builds go green-but-stale, bump cache key version suffix `v2`
