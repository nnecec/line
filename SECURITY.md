# Security policy

## Reporting a vulnerability

Use [GitHub private vulnerability reporting](https://github.com/nnecec/Line/security/advisories/new). Do not open a public issue for an unpatched vulnerability and do not include private window titles, file paths, credentials, or user data in a public report.

Include the affected commit or version, macOS version, reproduction steps, expected impact, and any proof of concept that can be shared safely. A maintainer will acknowledge the report when it has been reviewed and will coordinate disclosure if a fix is required.

## Supported code

Security fixes target `main` and the latest published release. Older snapshots and locally modified builds are not maintained. The upstream [MrKai77/Loop](https://github.com/MrKai77/Loop) project has its own maintenance and disclosure process.

## Security boundaries

Line requires macOS Accessibility permission to move and resize windows. A process that can invoke the `line://` URL scheme can request actions against the currently selected window. The URL scheme is a local automation interface, not an authentication boundary.

Line dynamically loads private SkyLight symbols for optional window-management behavior. Missing symbols must disable the related feature without bypassing macOS permission checks.

Official binaries are the GitHub Releases produced by the **Publish** workflow on protected `main`: Apple Development–signed (not Developer ID), unnotarized installable packages with SHA-256 checksums (and Actions provenance when enabled), plus Sparkle EdDSA signatures for the zip enclosure after the appcast PR is merged. Treat only assets from this repository’s Releases page as official. Optional Developer ID + notarization remains available in a separate workflow for maintainers who enroll in the Apple Developer Program.
