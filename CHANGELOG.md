# Changelog

This file records user-visible changes made after the repository's open source engineering cleanup. Earlier fork history remains available in Git.

## Unreleased

### Added

- Added open source contribution, security, support, privacy, architecture, release, and third-party license documentation.
- Added CodeQL, Gitleaks, Dependabot, immutable Action pins, issue forms, CODEOWNERS, and artifact attestation support.
- Added regression tests for Sparkle startup recovery, log redaction, appcast updates, canonical project links, and stash overlap behavior.

### Changed

- Sparkle is now the only update implementation, with a recoverable unavailable state and retry controls.
- Stable releases now use Developer ID signing, Apple notarization, checksums, draft asset verification, immutable release-safe recovery, and a reviewed appcast pull request.
- Settings are explicitly local because the app does not ship an iCloud entitlement.
- Logging removes private window, path, URL, and error details in every build; production additionally defaults to warning and error messages.

### Fixed

- Removed a sandbox-only Sparkle launcher configuration that could prevent the updater from starting.
- Stashing a window now replaces only same-screen, same-edge windows that no longer retain enough individually targetable space.

### Removed

- Removed the legacy ZIP updater, privileged installer helper, related authorization code, and ZIPFoundation dependency.
- Removed obsolete implementation plans, broken grid debug scripts, stale test summaries, and unused logo concept pages.
