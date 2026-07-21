## Summary

Describe the user-visible change and why it is needed.

## Brand / docs (if applicable)

- [ ] User-facing copy follows [docs/BRAND.md](../docs/BRAND.md) (EN default; ZH via localization or `*.zh-Hans.md`)
- [ ] Screenshots redact window titles, paths, and personal data
- [ ] Install or signing claims match [docs/RELEASES.md](../docs/RELEASES.md)

## Verification

- [ ] `make test-unit` (or the equivalent `xcodebuild test` with `-skip-testing:LineTests/EndToEndIntegrationTests`)
- [ ] `mint run swiftformat --lint . --reporter github-actions-log`
- [ ] Debug or Release build as appropriate (`make build` / `make build-release`)
- [ ] If this PR changes real-window behavior: `make test-integration` with Accessibility granted, or explain why it was skipped
- [ ] If this PR touches calculator / geometry code: `make test-coverage` (or rely on the CI calculator floor)
- [ ] Multi-display / Stage Manager manual check when the change affects layout

## Safety and compatibility

- [ ] No secrets, private window titles, local paths, or personal data were added.
- [ ] Update, signing, entitlement, or private API changes are documented.
- [ ] New user-facing text is localized or intentionally language-neutral.
