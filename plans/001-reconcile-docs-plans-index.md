# Plan 001: Reconcile docs/plans index with reality

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 2205ed1..HEAD -- docs/plans/`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: docs
- **Planned at**: commit `2205ed1`, 2026-07-22

## Why this matters

`docs/plans/README.md` still claims baseline `79ff450` and lists wrong numbering
and TODO statuses. Many plans are DONE in their own front-matter and tests
exist (`WindowEngineTests`, `GridGeometryTests`), but the index still says TODO.
Agents and maintainers re-do finished work or miss remaining items (e.g.
`004-temp-file-cleanup`).

## Current state

- `docs/plans/README.md` — stale index (wrong # → title mapping; many TODOs)
- Individual plan files have their own **状态** front-matter:
  - DONE: 001, 002, 003, 005, 007, 008, 009, 011, 012 (verify each file header)
  - TODO remaining: 004-temp-file-cleanup, and check 006/010 headers vs tests on disk
- Tests that prove completion:
  - `LineTests/WindowEngineTests.swift` (plan 006)
  - `LineTests/GridGeometryTests.swift` (plan 010)

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| List plan headers | `for f in docs/plans/*.md; do echo "=== $f"; head -8 "$f"; done` | Shows status per file |
| List tests | `ls LineTests/*.swift` | Includes WindowEngineTests, GridGeometryTests |

## Scope

**In scope**:
- `docs/plans/README.md` only

**Out of scope**:
- Changing plan body content of 001–012 except via README status table
- Application source code
- Root `plans/` (this improve batch)

## Git workflow

- Branch: `advisor/001-reconcile-docs-plans-index`
- Commit message style: `docs: reconcile docs/plans index with completed work`
- Do NOT push or open a PR unless instructed

## Steps

### Step 1: Inventory each plan file status

Run the list-headers command. Build a table of filename → status from each file's **状态** line. Cross-check:
- If `LineTests/WindowEngineTests.swift` exists → 006 DONE
- If `LineTests/GridGeometryTests.swift` exists → 010 DONE
- If plan header says TODO but tests clearly implement it, mark DONE with a note

**Verify**: inventory list has 12 plan files + accurate DONE/TODO

### Step 2: Rewrite docs/plans/README.md

Rewrite the index so:
1. **审计基准** notes original was `79ff450`; reconciled on `2205ed1` / 2026-07-22
2. Status table uses **actual filenames** as source of truth (001-accessibility-manager-tests = AccessibilityManager tests, NOT URL length)
3. Status column matches step 1
4. Dependency notes updated for remaining TODOs only
5. Remove or update "未审计区域" that claims tests don't exist when they do
6. Mention new improve plans live under root `plans/` (do not merge the two numbering systems)

**Verify**: `rg -n "TODO|DONE" docs/plans/README.md` shows consistent status; no claim that WindowEngine/GridGeometry lack tests if files exist

## Test plan

- Docs only — no unit tests

## Done criteria

- [ ] `docs/plans/README.md` status table matches each plan file's **状态** (and test presence for 006/010)
- [ ] Numbering/title mapping matches actual filenames
- [ ] No files outside scope modified
- [ ] Commit created on the branch above

## STOP conditions

- A plan file has contradictory status and you cannot determine DONE vs TODO from tests
- You would need to edit application Swift to "complete" a plan

## Maintenance notes

- Future plan completions must update both the plan front-matter and this README
- Root `plans/` is the new improve-skill backlog; `docs/plans/` is the legacy 2026-07-15 batch
