# Contributing to Line

Line is a macOS window manager written in Swift and SwiftUI. The project targets macOS 26 and uses some dynamically loaded private SkyLight APIs. Changes should preserve a usable fallback when a private symbol is unavailable.

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

Run the core local checks below. CI also performs an unsigned archive smoke test for the Release scheme.

在提交 PR 前运行完整验证：

```bash
make test           # 所有测试
make lint           # SwiftFormat 检查
make build-release  # Release 构建验证
```

或使用详细命令：

```bash
xcodebuild -project Line.xcodeproj -scheme Line -configuration Debug CODE_SIGNING_ALLOWED=NO build
xcodebuild test -project Line.xcodeproj -scheme Line -destination 'platform=macOS'
xcodebuild -project Line.xcodeproj -scheme "Line (GH ACTIONS)" -configuration Release -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build
ruby scripts/release/update_appcast_test.rb
mint run swiftformat --lint . --reporter github-actions-log
gitleaks git . --redact
gitleaks dir . --redact
```

Tests that manipulate real windows require Accessibility permission. Unit tests should use policy or calculation types that do not require permission whenever possible.

## Engineering rules

- Keep application and UI work on the main actor where AppKit requires it.
- Put window geometry calculations in testable domain types instead of views or event monitors.
- Treat window titles, file paths, URLs, and application content as private. Do not add them to public logs, fixtures, screenshots, or issues.
- Keep Sparkle as the only update implementation. Changes to signing, appcast generation, entitlements, or release URLs need tests and release documentation updates.
- Access SkyLight through the existing symbol loader and preserve graceful fallback behavior.
- Add user-facing strings to `Line/Localizable.xcstrings`.
- Do not commit credentials, certificates, provisioning profiles, keychains, generated archives, DerivedData, or local planning notes.

## Pull requests

Keep each pull request focused. Describe the user-visible behavior, tests run, affected permissions, and any compatibility risk. Include screenshots for UI changes, with personal information and window titles removed.

New behavior should include tests at the narrowest stable seam. Bug fixes should include a regression test when the failing behavior can be reproduced without controlling another application.

By contributing, you agree that your contribution is distributed under the repository's [GNU General Public License v3](LICENSE).
