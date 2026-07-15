# Release process

Official binaries come from GitHub Actions. Local Xcode archives are development artifacts unless the same signing, notarization, Sparkle, and verification steps are completed.

## Unsigned release without an Apple Developer membership

The `Unsigned Release` workflow builds installable DMG and ZIP packages without Apple signing credentials. Push a three-component version tag for a commit on `main` to publish automatically:

```bash
git tag v1.2.3
git push origin v1.2.3
```

The workflow can also be dispatched manually from `main` with a version input. It creates `Line-unsigned.dmg`, `Line-unsigned.zip`, and `SHA256SUMS.txt`, verifies the uploaded assets, records GitHub build provenance, and then publishes a GitHub prerelease. The build number is the commit count on `main`, and one semantic version tag is allowed per release commit.

These packages are not signed with a Developer ID and are not notarized. macOS may require the user to approve the app manually in Privacy & Security. The unsigned workflow does not update `appcast.xml`; Sparkle updates still require an archive signed with the private key matching `SPARKLE_PUBLIC_ED_KEY`.

Use the same packaging flow locally:

```bash
VERSION=1.2.3 scripts/release/build_unsigned_package.sh
```

Set `BUILD_NUMBER` to override the default Git commit count or `OUTPUT_DIR` to choose another destination. By default, packages are written to `dist/`.

## Repository setup

Before the first release:

1. Create the public `nnecec/Line` repository and make `main` the default branch.
2. Protect `main`. Require CI, Lint, CodeQL, and Secret Scan, require pull requests, block force pushes and branch deletion, and require review for workflow changes.
3. Enable secret scanning, push protection, Dependabot alerts, private vulnerability reporting, immutable releases, and GitHub Actions artifact attestations.
4. Create protected GitHub environments named `development-release` and `stable-release`. Require maintainer approval for both and restrict their deployment branches to `main`.
5. Allow the stable release workflow to create `automation/appcast-*` branches and pull requests. It does not push directly to `main`.

## Required secrets

Store signing credentials in the protected environments, not in repository files:

| Secret | Purpose |
| --- | --- |
| `DEVELOPER_ID_CERT_BASE64` | Base64-encoded Developer ID Application certificate and private key in PKCS#12 format |
| `P12_PASSWORD` | Password for the PKCS#12 file |
| `KEYCHAIN_PASSWORD` | Temporary CI keychain password |
| `REPOSITORY_POLICY_TOKEN` | Fine-grained token with read-only repository Administration permission, used only to require release immutability before publication |
| `APPLE_TEAM_ID` | Apple Developer team identifier |
| `APPLE_ID` | Apple account used by `notarytool` |
| `APPLE_ID_PWD` | App-specific password used by `notarytool` |
| `SPARKLE_PRIVATE_KEY` | Base64-encoded 32-byte Ed25519 seed matching `SPARKLE_PUBLIC_ED_KEY` |

The Sparkle private key is available only to the appcast signing step. Certificate and Apple credentials are limited to their signing or notarization steps.

## Stable release

Update `VERSION` and `BUILD_NUMBER` in `Line/Config.xcconfig` through a reviewed pull request before releasing. The version must use three numeric components, and the build number must be a positive integer that has not shipped before.

After that pull request is merged, dispatch the `Release` workflow from `main` with the same version, such as `1.4.4`.

The workflow:

1. Validates the version and monotonically increasing build in source control, branch, public Sparkle key, existing tag, appcast, and existing release state.
2. Archives with Developer ID and exports the signed app.
3. Notarizes and staples the app, then verifies it with `codesign`, `stapler`, and `spctl`.
4. Creates a Sparkle ZIP and notarized DMG, plus `SHA256SUMS.txt`.
5. Creates GitHub Actions provenance attestations.
6. Uploads assets to a draft release, downloads them again, and verifies their names and checksums.
7. Publishes the immutable GitHub Release, verifies its release and asset attestations, verifies Actions provenance, and inspects the released app's signature, Team ID, version, update feed, and public key.
8. Derives the public key from the protected Sparkle private seed, requires it to match the key embedded in the verified app, signs the ZIP, and validates the generated appcast XML.
9. Opens an `automation/appcast-vX.Y.Z` pull request. The update feed changes only after that pull request passes CI and is merged.

Publishing the Release before opening the appcast pull request avoids an update feed that points to missing assets. If Release publication succeeds but appcast PR creation fails, rerun the same workflow from the same `main` commit. The workflow requires every published asset, verifies the immutable Release attestation and Actions provenance, inspects the signed app, and rebuilds the appcast entry from the released ZIP. The release timestamp makes that entry deterministic. If an appcast branch or pull request already exists, its feed must match the regenerated result.

If release immutability was not enabled, the workflow stops before loading the Sparkle private key or updating the feed. Remove that mutable release, enable immutability, and rerun from the same commit.

## Development builds

The `Development Build` workflow always creates an unsigned verification artifact without loading signing credentials. It can run on a branch and can comment on a matching pull request.

The optional prerelease job runs only when the workflow is dispatched from `main`. It uses the protected `development-release` environment, creates a Developer ID signed and notarized ZIP, uploads it to a draft, verifies the downloaded checksum, and then publishes a uniquely tagged immutable prerelease. Rerunning an already published prerelease verifies its assets and exits without attempting to modify them.

## Manual verification

After a stable release and appcast merge:

```bash
gh release download vX.Y.Z --pattern 'Line.zip' --pattern 'Line.dmg' --pattern 'SHA256SUMS.txt'
gh release verify vX.Y.Z
gh release verify-asset vX.Y.Z Line.zip
gh attestation verify Line.zip --repo nnecec/Line
shasum -a 256 -c SHA256SUMS.txt
codesign --verify --deep --strict /Applications/Line.app
spctl --assess --type execute --verbose=2 /Applications/Line.app
```

Open the previous official version, run Check for Updates, install the new version, and confirm the version and build number after relaunch.
