# Privacy

Line does not require an account and does not include product analytics. Its primary work happens locally through macOS Accessibility APIs.

## Data Line can access

Accessibility permission lets Line inspect window geometry, application identity, focus state, and window titles so it can select and move windows. Window titles can contain document names or other private information. Application logs do not record titles, full file paths, full URLs, clipboard contents, or document content in any build.

Settings are stored locally through the Defaults package. Grid memory persists only an application bundle identifier, display identifier, and grid dimensions. To distinguish multiple windows from the same application, Line temporarily keeps process and window identifiers in memory; those identifiers are bounded, never persisted, and cleared when the application terminates, Accessibility access is revoked, or Line quits. Current builds do not ship an iCloud entitlement.

The planned Window Scene design is also local-only and must not extend this data boundary. A future versioned Scene document may contain a Scene/placement ID, name, bundle identifier, non-content Accessibility role/subrole or validated identifier, relative visible-frame layout, and display topology role/relationship. It must not persist window titles, document names, full paths, full URLs, clipboard or document content, hashes derived from that content, PID, CGWindowID, CG display ID, Space ID, or launch arguments. Runtime candidates and Prepared Resize values are discarded after apply. Scene receipts and logs may expose only IDs, bundle identifiers, counts, statuses, and error codes; they must not include titles, paths, URLs, AX dumps, or raw error text. Ambiguous matches are user-choice-or-skip, and apply is one-shot best-effort with per-placement reporting, not a transaction.

## Network access

Line uses Sparkle to read an update feed hosted on GitHub and to download an update after approval. Automatic update checks can be disabled in the About settings. Blocking GitHub and GitHubusercontent connections disables update checks and downloads but does not disable window management.

Line does not send window information to the update server.

## Diagnostics

Logs may contain application state, action types, and error codes. Before sharing a log or screenshot, remove names, window titles, file paths, URLs, and any content belonging to another person or organization.

Security-sensitive reports should use the private process in [SECURITY.md](../SECURITY.md).
