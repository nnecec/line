# Privacy

Line does not require an account and does not include product analytics. Its primary work happens locally through macOS Accessibility APIs.

## Data Line can access

Accessibility permission lets Line inspect window geometry, application identity, focus state, and window titles so it can select and move windows. Window titles can contain document names or other private information. Application logs do not record titles, full file paths, full URLs, clipboard contents, or document content in any build.

Settings are stored locally through the Defaults package. Grid memory persists only an application bundle identifier, display identifier, and grid dimensions. To distinguish multiple windows from the same application, Line temporarily keeps process and window identifiers in memory; those identifiers are bounded, never persisted, and cleared when the application terminates, Accessibility access is revoked, or Line quits. Current builds do not ship an iCloud entitlement.

## Network access

Line uses Sparkle to read an update feed hosted on GitHub and to download an update after approval. Automatic update checks can be disabled in the About settings. Blocking GitHub and GitHubusercontent connections disables update checks and downloads but does not disable window management.

Line does not send window information to the update server.

## Diagnostics

Logs may contain application state, action types, and error codes. Before sharing a log or screenshot, remove names, window titles, file paths, URLs, and any content belonging to another person or organization.

Security-sensitive reports should use the private process in [SECURITY.md](../SECURITY.md).
