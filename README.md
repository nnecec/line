# Line

Line is a keyboard, mouse, and grid-driven window manager for macOS. It is a personal fork of [MrKai77/Loop](https://github.com/MrKai77/Loop), based on upstream commit [9661bcb](https://github.com/MrKai77/Loop/tree/9661bcbba0ba6dae38838d712998f76ebd57cc66).

Line targets macOS 26 and requires Accessibility permission to move and resize windows.

## Features

- Standard and custom window actions
- Keyboard and middle-click triggers
- Grid-based placement on multiple displays
- Window cycling, padding, snapping, and edge stashing
- Configurable appearance and app icons
- Local automation through the `line://` URL scheme
- Signed updates through Sparkle

## Install

Official binaries are published on the repository's [GitHub Releases](https://github.com/nnecec/Line/releases) page. Release artifacts built by the protected workflow are Developer ID signed, Apple-notarized, accompanied by SHA-256 checksums, and covered by GitHub artifact attestations.

Until an official release is available, build Line from source:

```bash
git clone https://github.com/nnecec/Line.git
cd Line
open Line.xcodeproj
```

Do not install binaries shared through issues, pull requests, or unrelated download sites.

## Build and test

Use Xcode 26.4 or a compatible Xcode 26 release. The `Line` scheme is used for local development and tests. `Line (GH ACTIONS)` exercises the release configuration used by CI.

**快速开始**:

```bash
# 运行所有测试
make test

# 运行测试并查看覆盖率
make test-coverage

# Debug 构建
make build

# 查看所有命令
make help
```

**详细命令** (如果不使用 Makefile):

```bash
xcodebuild -resolvePackageDependencies -project Line.xcodeproj -scheme Line
xcodebuild -project Line.xcodeproj -scheme Line -configuration Debug CODE_SIGNING_ALLOWED=NO build
xcodebuild test -project Line.xcodeproj -scheme Line -destination 'platform=macOS'
xcodebuild -project Line.xcodeproj -scheme "Line (GH ACTIONS)" -configuration Release -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build
ruby scripts/release/update_appcast_test.rb
```

SwiftFormat is pinned through Mint:

```bash
brew install mint
mint run swiftformat --lint . --reporter github-actions-log
```

Luminare and Scribe are pinned to exact revisions in `Package.resolved`. Review their upstream changes before updating those revisions.

## Architecture and automation

- [Architecture](docs/ARCHITECTURE.md)
- [URL scheme](docs/URL_SCHEME.md)
- [Release process](docs/RELEASES.md)
- [Privacy](docs/PRIVACY.md)

Line uses Sparkle as its only updater. Stable releases are built from protected `main`. The workflow publishes and verifies the GitHub Release before opening a pull request that updates `appcast.xml`. The update tool keeps older feed entries and replaces the current version idempotently.

## Contributing and support

Read [CONTRIBUTING.md](CONTRIBUTING.md) before sending a pull request. Use GitHub's issue forms for bugs and feature requests. Security reports must follow [SECURITY.md](SECURITY.md), and general support expectations are in [SUPPORT.md](SUPPORT.md).

Project participation follows the [Code of Conduct](CODE_OF_CONDUCT.md). Dependency and asset notices are recorded in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Logo and icons

Editable logo sources and final exports live in [`logo/`](logo/LOGO.md).

## License and upstream credit

Line is distributed under the [GNU General Public License v3](LICENSE). The original design and implementation came from [MrKai77/Loop](https://github.com/MrKai77/Loop). Review that project for upstream documentation, releases, and community support.
