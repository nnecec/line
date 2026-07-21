# Logo and brand assets

Brand strategy, palette, tagline, and channel rules: [docs/BRAND.md](../docs/BRAND.md).  
Social layouts (composited from this logo): [assets/brand/](../assets/brand/).

## Source of truth

- [`../logo.png`](../logo.png) — **1000×1000** PNG mark (transparent; near-white fill ≈ `#F8F8F8`)

This file is the only marketing logo. Do not add alternate marks under `logo/` or `assets/brand/`.

## App icons

Runtime app icons and menu bar assets live in the Xcode project:

- `Line/Resources/AppIcon-Custom.icon/` — primary app icon
- `Line/Assets.xcassets/menubarIcon.imageset/` — menu bar template
- `Line/Assets.xcassets/App Icons/AppIcon-Custom.appiconset/` — catalog entry

## Brand tokens (marketing, from logo)

| Token | Hex |
| --- | --- |
| Mark / paper | `#F8F8F8` |
| Ink | `#0A0A0A` |
| Panel | `#161616` |
| Mute | `#8C8C8C` |

Tagline: **Snap to the line.** / **一线到位。**

## Editing

Keep `logo.png` square and free of personal window titles or screenshots. When replacing the mark, update `logo.png` in the same commit and update icon sets only if the product icon is intentionally changing. After a logo change, run:

```bash
python3 scripts/brand/generate_assets.py
```
