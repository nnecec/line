# Contributing to Line

Line is a **native macOS** window manager (Swift / SwiftUI) with **first-class grid** layout, **multi-display** support, and a focus on **performance**. The project targets macOS 26 and uses some dynamically loaded private SkyLight APIs. Changes should preserve a usable fallback when a private symbol is unavailable.

Brand and public messaging: [docs/BRAND.md](docs/BRAND.md) (English default; Chinese tagline **一线到位。**).

## Before you start

Search existing issues and pull requests before opening a new one. Use the bug report form for reproducible behavior and the feature request form for product proposals. Report security problems through GitHub's private vulnerability reporting flow described in [SECURITY.md](SECURITY.md).

You need:

- macOS 26
- Xcode 26.4 or a compatible Xcode 26 release
- Mint for the pinned SwiftFormat version
- Gitleaks for local secret scans

```bash
brew install mint gitleaks
xcodebuild -resolvePackageDependencies -project Line.xcodeproj -scheme Line
```

## Build and test

Run the core local checks below. CI splits **unit** tests (required) from **integration** tests (real windows; usually skipped on GitHub-hosted runners).

Before opening a pull request:

```bash
make test-unit         # required CI path
make lint              # SwiftFormat
make build-release     # unsigned Release configuration
# optional when you changed real-window behavior:
make test-integration  # needs Accessibility + a frontmost window
make test-coverage     # unit coverage + calculator floor
```

Equivalent detailed commands:

```bash
xcodebuild -project Line.xcodeproj -scheme Line -configuration Debug CODE_SIGNING_ALLOWED=NO build
xcodebuild test -project Line.xcodeproj -scheme Line -destination 'platform=macOS' \
  -skip-testing:LineTests/EndToEndIntegrationTests
xcodebuild -project Line.xcodeproj -scheme "Line (GH ACTIONS)" -configuration Release \
  -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build
ruby scripts/release/update_appcast_test.rb
mint run swiftformat --lint . --reporter github-actions-log
gitleaks git . --redact
gitleaks dir . --redact
```

### Test layers

| Layer | What it proves | CI job |
| --- | --- | --- |
| Unit / policy / calculator | Geometry and state without controlling other apps | **Unit Tests and Coverage** (required) |
| End-to-end integration | `WindowActionEngine` against a real frontmost window | **Integration Tests (Accessibility)** — cases `XCTSkip` without permission |
| Manual | Multi-display, Stage Manager, grid UI, drag capture | PR checklist |

Tests that manipulate real windows require Accessibility permission. Prefer policy or calculation types that do not need permission. When you touch a large coordinator or UI file, add or extend tests only for the pure seam you changed — do not expand the whole file for coverage theater.

Calculator coverage for `WindowActionCalculator`, `CustomWindowActionCalculator`, `SpecialActionCalculator`, and `GridGeometry` is gated at a minimum line percentage in CI (`scripts/ci/check_calculator_coverage.sh`).

## Engineering rules

- Keep application and UI work on the main actor where AppKit requires it.
- Put window geometry calculations in testable domain types instead of views or event monitors.
- Treat window titles, file paths, URLs, and application content as private. Do not add them to public logs, fixtures, screenshots, or issues.
- Keep Sparkle as the only update implementation. Changes to signing, appcast generation, entitlements, or release URLs need tests and release documentation updates. Public releases use the **Publish** workflow and Conventional Commits; see [docs/RELEASES.md](docs/RELEASES.md).
- Access SkyLight through the existing symbol loader and preserve graceful fallback behavior.
- Add user-facing strings to `Line/Localizable.xcstrings`.
- Do not commit credentials, certificates, provisioning profiles, keychains, generated archives, DerivedData, or local planning notes.

## Pull requests

Keep each pull request focused. Describe the user-visible behavior, tests run, affected permissions, and any compatibility risk. Include screenshots for UI changes, with personal information and window titles removed.

New behavior should include tests at the narrowest stable seam. Bug fixes should include a regression test when the failing behavior can be reproduced without controlling another application.

By contributing, you agree that your contribution is distributed under the repository's [GNU General Public License v3](LICENSE).
