# Release process

Line publishes **installable GitHub Release assets** from Actions without requiring an Apple Developer Program membership. Packages are **not** Developer ID signed and **not** notarized. In-app updates still use **Sparkle** and a signed `appcast.xml` feed.

For local day-to-day Development signing (Accessibility testing only), see [Local development signing](#local-development-signing) at the end.

## Supported publish path (current)

Workflow: **`Publish`** (`.github/workflows/publish.yml`).

| Trigger | Only `workflow_dispatch` on **`main` tip** |
| --- | --- |
| Version | **Git tags** `vX.Y.Z` from [Conventional Commits](https://www.conventionalcommits.org/) via **semantic-release** |
| Assets | `Line-X.Y.Z.zip`, `Line-X.Y.Z.dmg`, `SHA256SUMS.txt` |
| GitHub Release | **Full release** (Latest), not prerelease |
| Code signature | `CODE_SIGNING_ALLOWED=NO` |
| Sparkle | After Release succeeds, open `automation/appcast-vX.Y.Z` PR; **merge to enable in-app updates** |
| Changelog | GitHub Release body only (no auto `CHANGELOG.md` commit) |

### How to publish

1. Merge releasable commits to `main` using Conventional Commits (`feat:`, `fix:`, `perf:`, `BREAKING CHANGE`, etc.).
2. Wait until **CI** and **Lint** are green on that tip commit.
3. Open **Actions → Publish → Run workflow** on `main`.
   - `dry_run: true` — compute version, build packages, **do not** tag / Release / appcast.
   - `dry_run: false` — full publish when there are releasable commits.

```bash
gh workflow run Publish --ref main -f dry_run=false
gh run watch
```

### Version rules

| Commits since last `v*` tag | Next version |
| --- | --- |
| only `fix` / `perf` / … patch types | patch (`x.y.z+1`) |
| at least one `feat` | minor |
| breaking (`!` or `BREAKING CHANGE`) | major |
| no releasable commits | **skip** (job succeeds, nothing published) |

**First release** (no prior `vX.Y.Z` tags): the workflow seeds a local-only bootstrap tag `v0.0.0` at the root commit so semantic-release stays on the `0.x` / conventional path (`0.0.1` / `0.1.0` / `1.0.0`) instead of jumping to `1.0.0` by default. That bootstrap tag is **not** pushed.

`CFBundleShortVersionString` is the computed marketing version. `CFBundleVersion` is `git rev-list --count HEAD` on the release commit. `Line/Config.xcconfig` may remain `0.0.0` for day-to-day development; the package build injects VERSION / BUILD_NUMBER at archive time.

### Asset names

```text
Line-0.1.0.zip
Line-0.1.0.dmg
SHA256SUMS.txt
```

Tag and Release name: `v0.1.0`. Do not use `Line-unsigned.*`.

### Order of operations

1. Require dispatch from current `main` tip; require successful **CI** + **Lint** runs for that SHA.
2. If the latest GitHub Release already has the three assets but `appcast.xml` lacks that version → **appcast-only** repair (download assets, sign zip, open PR). No new tag.
3. Otherwise run **semantic-release**:
   - analyze commits → if no release, exit successfully;
   - **build** packages (`scripts/release/build_package.sh`) before git/GitHub publish;
   - create tag + **full** GitHub Release with assets;
4. Attest build provenance (when not dry-run).
5. Append distribution notes on the Release (not notarized; appcast PR required for Sparkle).
6. Sign `Line-X.Y.Z.zip` with `SPARKLE_PRIVATE_KEY`, update `appcast.xml`, open **`automation/appcast-vX.Y.Z`** PR.

If step 6 fails after step 3 succeeded, the Release **remains**. Re-run **Publish** on the same main tip to take the **appcast-only** path.

### Secrets

| Secret | Required for |
| --- | --- |
| `SPARKLE_PRIVATE_KEY` | Ed25519 seed (base64) matching `SPARKLE_PUBLIC_ED_KEY` in `Line/Config.xcconfig` — zip signing + appcast |

No Apple Developer certificates are required for **Publish**.

Store the private key only in GitHub Actions secrets. Never commit it.

### Local package build

```bash
VERSION=0.1.0 BUILD_NUMBER=42 scripts/release/build_package.sh
# writes dist/Line-0.1.0.zip, dist/Line-0.1.0.dmg, dist/SHA256SUMS.txt
```

`scripts/release/build_unsigned_package.sh` is a thin wrapper around the same script.

### Trust model

| Channel | Trust |
| --- | --- |
| GitHub Release download | SHA-256 + optional Actions provenance; **manual** Gatekeeper approval |
| Sparkle in-app update | EdDSA of the zip against the public key embedded in the app; feed only after appcast PR merge |

## Developer ID / notarized workflow (optional, paid)

`.github/workflows/release.yml` remains for maintainers who later enroll in the Apple Developer Program. It is **not** required for the open-source Publish path above. See git history and that workflow for certificate, notarization, and immutable-release requirements.

## Local development signing

Local builds should use an Apple Development certificate from a free Apple ID when testing Accessibility. This is not a release credential.

```bash
VERSION=0.0.1 scripts/release/build_local_signed_package.sh
```

Writes `Line-local.dmg` / `Line-local.zip` under `dist/`. Not for public distribution.
