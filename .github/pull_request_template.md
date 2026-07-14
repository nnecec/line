## Summary

Describe the user-visible change and why it is needed.

## Verification

- [ ] `xcodebuild -project Line.xcodeproj -scheme Line -configuration Debug CODE_SIGNING_ALLOWED=NO build`
- [ ] `xcodebuild test -project Line.xcodeproj -scheme Line -destination 'platform=macOS'`
- [ ] `mint run swiftformat --lint . --reporter github-actions-log`
- [ ] I tested any changed window behavior with more than one display when applicable.

## Safety and compatibility

- [ ] No secrets, private window titles, local paths, or personal data were added.
- [ ] Update, signing, entitlement, or private API changes are documented.
- [ ] New user-facing text is localized or intentionally language-neutral.
