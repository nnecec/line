# Release process

Line publishes **installable GitHub Release assets** from Actions **without** an Apple Developer Program membership ($99). Packages are signed with a free **Apple Development** certificate so Accessibility permission can stick, but they are **not** Developer ID signed and **not** notarized. In-app updates still use **Sparkle** and a signed `appcast.xml` feed.

## Release notes

Use the English-default body in [RELEASE_NOTES_TEMPLATE.md](RELEASE_NOTES_TEMPLATE.md). Keep install honesty (Development signature, not notarized, Accessibility) in every public release.

## Why Development signing (not unsigned)

macOS Accessibility (TCC) keys off the app’s **code signature / designated requirement**, not Bundle ID alone. Unsigned / ad hoc builds change identity every rebuild, so System Settings may show Accessibility enabled while `AXIsProcessTrusted()` stays false.

Official Publish builds therefore **must** be Apple Development–signed. `ALLOW_UNSIGNED=1` is only for local compile checks.

## Supported publish path (current)

Workflow: **`Publish`** (`.github/workflows/publish.yml`).

| Trigger | Only `workflow_dispatch` on **`main` tip** |
| --- | --- |
| Version | **Git tags** `vX.Y.Z` from [Conventional Commits](https://www.conventionalcommits.org/) via **semantic-release** |
| Assets | `Line-X.Y.Z.zip`, `Line-X.Y.Z.dmg`, `SHA256SUMS.txt` |
| GitHub Release | **Full release** (Latest), not prerelease |
| Code signature | **Apple Development** (free Apple ID); not notarized |
| Sparkle | After Release succeeds, open `automation/appcast-vX.Y.Z` PR; **merge to enable in-app updates** |
| Changelog | GitHub Release body only (no auto `CHANGELOG.md` commit) |

### How to publish

1. Merge releasable commits to `main` using Conventional Commits (`feat:`, `fix:`, `perf:`, `BREAKING CHANGE`, etc.).
2. Wait until **CI** and **Lint** are green on that tip commit.
3. Ensure Publish secrets are set (see below), including the Development `.p12`.
4. Open **Actions → Publish → Run workflow** on `main`.
   - `dry_run: true` — compute version, build packages, **do not** tag / Release / appcast.
   - `dry_run: false` — full publish when there are releasable commits.
   - `version_bump: auto` — follow Conventional Commits (default).
   - `version_bump: patch` — treat `feat` commits as patch for this run; breaking changes still produce a major release.

```bash
gh workflow run Publish --ref main -f dry_run=false -f version_bump=auto
# Explicit patch release when the accumulated feature is intentionally patch-sized:
gh workflow run Publish --ref main -f dry_run=false -f version_bump=patch
gh run watch
```

### Version rules

| Commits since last `v*` tag | Next version |
| --- | --- |
| only `fix` / `perf` / … patch types | patch (`x.y.z+1`) |
| at least one `feat` | minor |
| breaking (`!` or `BREAKING CHANGE`) | major |
| no releasable commits | **skip** (job succeeds, nothing published) |

`version_bump: patch` is an explicit exception for intentionally patch-sized features. It only
downgrades `feat` from minor to patch; breaking commits remain major. Keep `auto` for normal releases.

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
3. Otherwise import the Development certificate, then run **semantic-release**:
   - analyze commits → if no release, exit successfully;
   - **build** Development-signed packages (`scripts/release/build_package.sh`) before git/GitHub publish;
   - create tag + **full** GitHub Release with assets;
4. Attest build provenance (when not dry-run).
5. Append distribution notes on the Release (Development-signed, not notarized; appcast PR required for Sparkle).
6. Sign `Line-X.Y.Z.zip` with `SPARKLE_PRIVATE_KEY`, update `appcast.xml`, open **`automation/appcast-vX.Y.Z`** PR.

CI and Publish pass `-skipMacroValidation` because GitHub-hosted runners cannot approve Swift macros
interactively. This is bounded by pinning Scribe and its macro implementation to the exact revision in
`Package.resolved`; review that revision whenever the dependency is upgraded.

If step 6 fails after step 3 succeeded, the Release **remains**. Re-run **Publish** on the same main tip to take the **appcast-only** path.

### Secrets

| Secret | Required for |
| --- | --- |
| `SPARKLE_PRIVATE_KEY` | Ed25519 seed (base64) matching `SPARKLE_PUBLIC_ED_KEY` in `Line/Config.xcconfig` — zip signing + appcast |
| `APPLE_DEVELOPMENT_CERT_BASE64` | Base64-encoded Apple Development `.p12` (certificate + private key) |
| `P12_PASSWORD` | Password for that `.p12` |
| `KEYCHAIN_PASSWORD` | Temporary CI keychain password (any strong random string) |
| `DEVELOPMENT_TEAM` | Optional. Team ID (default in script: `3F4PBYM8L4`) |

Store certificates and private keys only in GitHub Actions secrets. Never commit them.

#### Export the Development `.p12` (once)

1. Xcode → Settings → Accounts → manage certificates → ensure an **Apple Development** certificate exists (free Apple ID is enough).
2. Open **Keychain Access**, select the **Apple Development: …** certificate, and export as `.p12` with a password.
3. Base64-encode for the secret:

```bash
base64 -i LineDevelopment.p12 | pbcopy
```

Paste into repository secret `APPLE_DEVELOPMENT_CERT_BASE64`. Renew when the certificate expires (~1 year); users may need to re-grant Accessibility once after a cert change.

### Local package build

```bash
# Same path as Publish (Development-signed):
VERSION=0.1.0 BUILD_NUMBER=42 scripts/release/build_package.sh
# writes dist/Line-0.1.0.zip, dist/Line-0.1.0.dmg, dist/SHA256SUMS.txt

# Unsigned only (Accessibility will not stick):
ALLOW_UNSIGNED=1 VERSION=0.1.0 scripts/release/build_package.sh
# or: scripts/release/build_unsigned_package.sh
```

### End-user install (unnotarized)

1. Download `Line-X.Y.Z.dmg` from [Releases](https://github.com/nnecec/Line/releases).
2. Drag Line to Applications.
3. First launch: **right-click → Open** (Gatekeeper; builds are not notarized).
4. System Settings → Privacy & Security → **Accessibility** → enable Line.
5. Quit and reopen Line; Settings should show Accessibility granted.

If you previously installed an **unsigned** build, reset once then re-grant:

```bash
tccutil reset Accessibility com.nnecec.Line
```

### Trust model

| Channel | Trust |
| --- | --- |
| GitHub Release download | SHA-256 + optional Actions provenance; Development code signature; **manual** Gatekeeper approval |
| Sparkle in-app update | EdDSA of the zip against the public key embedded in the app; feed only after appcast PR merge |

## Developer ID / notarized workflow (optional, paid)

`.github/workflows/release.yml` remains for maintainers who later enroll in the Apple Developer Program. It is **not** required for the open-source Publish path above. See that workflow for certificate, notarization, and immutable-release requirements.

## Local development signing helper

```bash
VERSION=0.0.1 scripts/release/build_local_signed_package.sh
```

Writes `Line-local.dmg` / `Line-local.zip` under `dist/` via Xcode Automatic signing. Prefer `build_package.sh` when matching the Publish artifact path.
