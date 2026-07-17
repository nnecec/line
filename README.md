# Line

<p align="center">
  <img src="logo.png" alt="Line logo" width="128" height="128">
</p>

Line is a keyboard, mouse, and grid-driven window manager for macOS. It is a personal fork of [MrKai77/Loop](https://github.com/MrKai77/Loop), based on upstream commit [9661bcb](https://github.com/MrKai77/Loop/tree/9661bcbba0ba6dae38838d712998f76ebd57cc66).

Line targets macOS 26 and requires Accessibility permission to move and resize windows.

## Features

- Standard and custom window actions
- Keyboard and middle-click triggers
- Grid-based placement on multiple displays
- Window cycling, padding, snapping, and edge stashing
- Configurable appearance and app icons
- Local automation through the `line://` URL scheme
- In-app updates through Sparkle (after the appcast PR for a release is merged)

## Install

Official packages are published on [GitHub Releases](https://github.com/nnecec/Line/releases) as:

- `Line-X.Y.Z.dmg`
- `Line-X.Y.Z.zip`
- `SHA256SUMS.txt`

These builds are produced on GitHub Actions with a free **Apple Development** signature so Accessibility permission can stick. They are **not** Developer ID signed and **not** notarized. First launch: right-click → **Open**, then enable Line under System Settings → Privacy & Security → **Accessibility**. Prefer assets from this repository’s Releases page only.

In-app **Check for Updates** uses Sparkle and the feed at [`appcast.xml`](appcast.xml) on `main`. That file is updated through a reviewable pull request after each publish; until that PR is merged, GitHub Releases may already have the new build while the app still reports “up to date.”

### Build from source

```bash
git clone https://github.com/nnecec/Line.git
cd Line
open Line.xcodeproj
```

### Maintainers: publish a release

1. Land Conventional Commits on `main` (`feat:`, `fix:`, …).
2. Ensure **CI** and **Lint** are green on the tip.
3. Run **Actions → Publish** (`dry_run` optional).

semantic-release chooses the next `vX.Y.Z` tag, builds packages, creates a full GitHub Release, then opens an appcast PR. Details: [docs/RELEASES.md](docs/RELEASES.md).

Required repository secrets:

- `SPARKLE_PRIVATE_KEY` (Ed25519 seed matching `SPARKLE_PUBLIC_ED_KEY` in `Line/Config.xcconfig`)
- `APPLE_DEVELOPMENT_CERT_BASE64`, `P12_PASSWORD`, `KEYCHAIN_PASSWORD` (free Apple Development `.p12` for Accessibility-stable Release builds)

See [docs/RELEASES.md](docs/RELEASES.md) for exporting the certificate.

## Build and test

Use Xcode 26.4 or a compatible Xcode 26 release. The `Line` scheme is for local development and tests. `Line (GH ACTIONS)` is the release configuration used by CI and Publish.

For local Accessibility testing, sign with an Apple Development identity (free Apple ID). See [docs/RELEASES.md](docs/RELEASES.md).

```bash
make test-unit         # required CI path
make test-integration  # needs Accessibility
make test-coverage     # unit + calculator floor
make build
make build-release
make help
```

```bash
VERSION=0.1.0 scripts/release/build_package.sh   # Development-signed dist/Line-0.1.0.{zip,dmg}
mint run swiftformat --lint . --reporter github-actions-log
```

## Architecture and automation

- [Architecture](docs/ARCHITECTURE.md)
- [URL scheme](docs/URL_SCHEME.md)
- [Release process](docs/RELEASES.md)
- [Privacy](docs/PRIVACY.md)
- [Logo assets](logo/LOGO.md)

## Contributing and support

Read [CONTRIBUTING.md](CONTRIBUTING.md) before sending a pull request. Use GitHub issue forms for bugs and features. Security: [SECURITY.md](SECURITY.md). Support: [SUPPORT.md](SUPPORT.md).

[Code of Conduct](CODE_OF_CONDUCT.md) · [Third-party notices](THIRD_PARTY_NOTICES.md)

## License and upstream credit

Line is distributed under the [GNU General Public License v3](LICENSE). The original design and implementation came from [MrKai77/Loop](https://github.com/MrKai77/Loop).
