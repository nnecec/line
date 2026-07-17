# Changelog

This file records user-visible changes made after the repository's open source engineering cleanup. Earlier fork history remains available in Git.

## Unreleased

### Added

- Added open source contribution, security, support, privacy, architecture, release, and third-party license documentation.
- Added CodeQL, Gitleaks, Dependabot, immutable Action pins, issue forms, CODEOWNERS, and artifact attestation support.
- Added regression tests for Sparkle startup recovery, log redaction, appcast updates, canonical project links, and stash overlap behavior.
- Documented logo assets under `logo/LOGO.md` and clarified pre-release install channels in the README.
- Split CI into unit tests (with a calculator coverage floor) and an explicit Accessibility integration job that reports skip counts.
- Added **Publish** workflow (semantic-release): Conventional Commits → `Line-X.Y.Z.{zip,dmg}` + GitHub Release + Sparkle appcast PR.

### Changed

- Sparkle is now the only update implementation, with a recoverable unavailable state and retry controls.
- Public distribution no longer requires Apple Developer ID: packages ship unnotarized as `Line-X.Y.Z` assets; appcast updates land via reviewed PR after publish.
- Settings are explicitly local because the app does not ship an iCloud entitlement.
- Logging removes private window, path, URL, and error details in every build; production additionally defaults to warning and error messages.
- Replaced the **Unsigned Release** (`Line-unsigned.*`) path with **Publish** asset naming and full (non-prerelease) GitHub Releases.

### Fixed

- Removed a sandbox-only Sparkle launcher configuration that could prevent the updater from starting.
- Stashing a window now replaces only same-screen, same-edge windows that no longer retain enough individually targetable space.

### Removed

- Removed the legacy ZIP updater, privileged installer helper, related authorization code, and ZIPFoundation dependency.
- Removed obsolete implementation plans, broken grid debug scripts, stale test summaries, and unused logo concept pages.
