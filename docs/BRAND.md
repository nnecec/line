# Line Brand System

**Default language: English.** Chinese is a first-class localization, not a second product.

This document is the long-lived brand source of truth for GitHub, the app, docs, and social. Visual exports belong under `logo/` and `assets/brand/` when generated.

---

## 1. Positioning

| Layer | Statement |
| --- | --- |
| **Category** | Native macOS window manager (menu-bar first) |
| **Who** | Power users, developers, designers who place windows with intent |
| **Job** | First-class grid layout, multi-display placement, and fast window actions on macOS |
| **Promise** | Grid as a first-class citizen; multi-display; high performance; native; open source |
| **Not** | Cloud SaaS, AI “agent” theater, playful consumer gimmicks, or a Loop clone brand |

**Lead with product value, not input methods or permission boilerplate.**  
Keyboard/mouse triggers and Accessibility stay in install / docs when factual — not in taglines, repo description, or social bios.

**One-line (EN):**  
Line is a native macOS window manager with first-class grid layout, multi-display support, and high performance. Open source.

**One-line (ZH):**  
Line 是一款原生 macOS 窗口管理器：以网格为核心、多屏幕、高性能、开源。

**Pillars (always prefer these in marketing):**

1. **Grid-first** — 网格优先  
2. **Multi-display** — 多屏幕支持  
3. **High performance** — 高性能  
4. **Native macOS** — macOS 原生应用  
5. **Open source** — 开源  

**Tagline options (pick one primary):**

| EN | ZH | Use |
| --- | --- | --- |
| **Snap to the line.** | **一线到位。** | Primary — product + social |
| Grid first. Multi-display. Native. | 网格优先。多屏。原生。 | Feature strip / cover subhead |
| Place windows with intent. | 有意图地摆放窗口。 | Docs / README subhead |
| Open source. Built for macOS. | 开源。为 macOS 而生。 | Trust / community |

**Recommended primary:** `Snap to the line.` / `一线到位。`

---

## 2. Brand idea (metaphor)

**The line** = window edge + snap guide + grid alignment + decision boundary.

**Logo is fixed.** Use repository-root [`logo.png`](../logo.png) only. Do not invent alternate marks, monograms, or “concept” logos for marketing.

| Do | Don't |
| --- | --- |
| Composite the shipping `logo.png` on dark fields | Redesign or replace the mark without an explicit product decision |
| Monochrome system derived from the logo’s near-white fill | Cyan / coral / rainbow “AI” accents that fight the logo |
| Sparse type, large negative space | Dense marketing walls, emoji spam |
| Credit Loop as upstream when relevant | Imply Line invented the whole category alone |

---

## 3. Voice & tone

| Trait | Means | Avoid |
| --- | --- | --- |
| **Precise** | Concrete product nouns: grid, multi-display, performance | “Revolutionary”, “seamless magic” |
| **Calm** | Short sentences; one idea per paragraph | Hype launches, fake urgency |
| **Native** | Speak as a real macOS app (SwiftUI/AppKit, menu bar) | Cross-platform fluff; leading with permissions |
| **Capability-first** | Grid, multi-display, speed, open source | Leading with keyboard/mouse or “Accessibility required” |
| **Honest** | Signing / install details only in install sections | Overclaim security or notarization |
| **Open** | Link issues, SECURITY, RELEASES | Gatekeeping tone |

**EN microcopy patterns**

- Prefer: “First-class grid. Multi-display. Native. Open source.”  
- Prefer: “Official packages are on GitHub Releases.”  
- Install-only: “Not Developer ID signed and not notarized.” (when true)

**ZH microcopy patterns**

- Prefer:「网格优先。多屏幕。高性能。原生。开源。」  
- Prefer:「官方包仅发布在 GitHub Releases。」  
- 安装说明里再写右键打开 / 辅助功能，不当主标语。

---

## 4. Visual system

### 4.1 Palette (from `logo.png`)

The shipping mark is a **near-white** solid (`#F8F8F8` / `#F8F8F8`) on **transparent**. Brand surfaces are dark neutrals so the logo stays legible. No secondary brand accent color unless the product UI already introduces one for functional reasons (e.g. system accent) — marketing stays monochrome.

| Token | Hex | Role |
| --- | --- | --- |
| `mark` | `#F8F8F8` | Logo fill (sampled from `logo.png`) |
| `ink` | `#0A0A0A` | Canvas, social backgrounds |
| `panel` | `#161616` | Cards, chips, inset panels |
| `mute` | `#8C8C8C` | Secondary labels on dark |
| `paper` | `#F8F8F8` | Primary type on dark (matches mark) |

**Ratio:** ~85% ink/panel · ~15% mark/mute. Do not add cyan, coral, or gradient brand colors to marketing assets.

### 4.2 Typography

| Role | Direction |
| --- | --- |
| Wordmark | Geometric sans, medium weight, tracking slightly open: **Line** |
| Marketing (EN) | Inter / SF Pro / system sans — short headlines |
| Marketing (ZH) | SF Pro / PingFang SC — match EN hierarchy, not word-for-word length |
| Code / URL scheme | SF Mono / JetBrains Mono: `line://…` |
| App UI | System (SF) — do not invent a second UI font family |

### 4.3 Logo usage

**Source of truth:** root [`logo.png`](../logo.png) (1000×1000, transparent, near-white mark). See [`logo/LOGO.md`](../logo/LOGO.md).

Social boards must **composite this file**, not redraw the symbol.

| Context | Spec |
| --- | --- |
| README / docs | Centered mark 96–128px; alt `Line logo` |
| GitHub social preview | 1280×640; `logo.png` left or center-left on `ink`; tagline + URL |
| App icon | Xcode catalogs only; do not invent parallel concept icons for brand kits |
| Menu bar | Existing template assets |
| Clear space | ≥ ¼ of mark height on all sides |
| Min size | Mark ≥ 24px digital; menu bar follows Apple HIG |

### 4.4 Photography / screenshot rules

- No real window titles, personal paths, or identifiable documents (aligns with privacy policy).
- Prefer abstract desktop + grid overlay, or redacted UI.
- Screenshot hero: dark desktop, subtle light snap guides if any, one focused window silhouette; keep frames monochrome-friendly.
- Format: WebP/PNG; README hero already at `assets/Screenshot.webp`.

---

## 5. GitHub surface map

GitHub is the **primary distribution and brand channel**.

| Surface | Brand job | EN default | ZH |
| --- | --- | --- | --- |
| Repository description | Search + first impression | Short one-liner | Optional org bio |
| README | Install truth + features + credit | Primary | Link `README.zh-Hans.md` |
| Releases | Trust + version story | Full notes EN | Optional ZH section |
| Issues / PR templates | Tone + safety | Existing templates | Keep EN fields; labels bilingual OK |
| SECURITY / SUPPORT / PRIVACY | Trust | EN source | ZH mirrors if published |
| Discussions / Wiki | Optional; prefer issues | EN | — |
| Social preview image | Share cards | Brand strip | Same art, EN copy |

### 5.1 Repository metadata (copy)

**Description (≤160 chars, EN):**  
`Native macOS window manager. First-class grid, multi-display, high performance. Open source.`

**Topics (suggested):**  
`macos` `window-manager` `swift` `swiftui` `grid-layout` `multi-display` `sparkle` `open-source` `menu-bar`

**Website:** GitHub Releases or project site when available.

### 5.2 README structure (canonical EN)

1. Logo + name  
2. One-line + fork credit (Loop + commit)  
3. Badges (optional: release, license, macOS 26)  
4. Features (bullets, no hype)  
5. Install (Releases, signing honesty, Accessibility)  
6. Screenshot  
7. Build from source  
8. Docs links  
9. Contributing / support / license  

Chinese: `README.zh-Hans.md` with the same sections; EN remains default entry.

### 5.3 Release notes template (EN)

```markdown
## Line X.Y.Z

### Highlights
- …

### Changes
- …

### Install
- `Line-X.Y.Z.dmg` / `Line-X.Y.Z.zip` / `SHA256SUMS.txt`
- Apple Development–signed; not Developer ID; not notarized.
- First launch: right-click → Open → enable Accessibility.

### Notes
- Sparkle feed updates after the appcast PR merges.
```

### 5.4 Issue / PR voice

- Titles: `[Bug]: …` / `[Feature]: …` (existing forms).  
- Always remind: redact titles, paths, personal data.  
- PR summary: user-visible change first, then verification checklist (existing template).

---

## 6. Bilingual documentation policy

| Rule | Detail |
| --- | --- |
| **Source of truth** | English for engineering docs (`docs/*`, SECURITY, CONTRIBUTING) |
| **Product UI** | `Localizable.xcstrings` — EN + zh-Hans (and others as needed) |
| **Public product docs** | EN primary; ZH as `*.zh-Hans.md` siblings or `/zh-Hans/` when site exists |
| **No mixed headings** | One language per document body; link across languages at the top |
| **Terminology** | Keep product names: Line, Sparkle, Accessibility; ZH may gloss once |

**Glossary (public)**

| EN | ZH |
| --- | --- |
| Window action | 窗口操作 |
| Grid | 网格 |
| Stash | 收纳 / 边缘收纳 |
| Cycle | 循环切换 |
| Keybind | 快捷键 |
| Middle-click trigger | 中键触发 |
| Accessibility | 辅助功能 |
| Appcast | Appcast（更新源） |
| Menu bar | 菜单栏 |

---

## 7. Social & content system

Platforms: **X**, **小红书**, **抖音** (+ optional Mastodon/Bluesky). GitHub Releases remain canonical for binaries.

### 7.1 Content pillars

1. **First-class Grid** — demos of grid placement (redacted UI).  
2. **Multi-display** — spanning and targeting screens.  
3. **High performance / native** — snappy actions, macOS-native feel.  
4. **Open source** — releases, checksums, install path (signing honesty only when shipping binaries).  
5. **Upstream honesty** — Loop credit; Line’s own direction.

Cadence suggestion: 1 release post per version · 1 craft/tip post every 1–2 weeks · optional privacy deep-dive only when needed.

### 7.2 X (Twitter)

- EN default; ZH replies OK.  
- Media: 16:9 brand strip or short screen capture.  
- Hashtags sparingly: `#macOS` `#WindowManager` (ZH 可加 `#Mac效率`).

**Launch template (EN):**  
`Line — native macOS window manager.  
First-class grid · multi-display · high performance · open source.  
Snap to the line.  
github.com/nnecec/Line`

**Release template (EN):**  
`Line vX.Y.Z is out.  
• …  
DMG + zip + SHA256 on GitHub Releases.`

### 7.3 小红书

- ZH primary; vertical 3:4 covers; first 2 lines must hook.  
- Title pattern: `Mac 窗口管理 | Line vX.Y.Z` / `网格优先`  
- Body: 网格 / 多屏 / 原生高性能 / 开源 → 演示 → GitHub 链接.  
- 安装细节（右键打开、辅助功能）放文末，不当主卖点.  
- Avoid fake “全网最强”; show real grid UI (redacted).

### 7.4 抖音 / 短视频

- 15–30s: grid + multi-display before/after; on-screen EN or ZH captions.  
- B-roll: grid overlay, multi-monitor placement, menu bar app.  
- End card: logo + `github.com/nnecec/Line` + tagline.  
- Audio: soft UI clicks or no music license risk; prefer original/light.

### 7.5 Social asset sizes

| Asset | Size | Notes |
| --- | --- | --- |
| GitHub Open Graph | 1280×640 | Dark, logo + tagline + URL |
| X post | 1600×900 or 1:1 | Same system |
| 小红书 cover | 1080×1440 | ZH headline large |
| 抖音 cover | 1080×1920 | End card safe zone |
| App icon | 1024×1024 | Xcode catalog |

Store generated masters under `assets/brand/` (create when assets exist).

---

## 8. Brand rollout plan

### Phase A — Foundation (now)

- [x] Document strategy (`docs/BRAND.md`)  
- [x] Brand board + social masters (`assets/brand/`, `scripts/brand/generate_assets.py`)  
- [x] Add `README.zh-Hans.md` linked from EN README  
- [x] Set GitHub repo description + topics + homepage (social preview image: Settings → General → Social preview → `assets/brand/og-github.png`)  
- [x] Marketing palette derived from `logo.png` (`#F8F8F8` mark + dark neutrals); generators composite `logo.png` only  

### Phase B — GitHub polish

- [x] Optional release badge / shields (version, license, macOS) on README  
- [x] Repo description / topics / homepage set to capability-first copy  
- [x] Release notes template with install honesty block ([RELEASE_NOTES_TEMPLATE.md](RELEASE_NOTES_TEMPLATE.md))  
- [x] CONTRIBUTING / SUPPORT brand tone pass  
- [ ] Upload Social preview image in repo Settings → `assets/brand/og-github.png`  

### Phase C — Multi-channel

- [x] Media kit + copy bank (`assets/brand/MEDIA_KIT.md`, `COPY_BANK.md`)  
- [x] Social masters regenerated with capability-first copy  
- [ ] X pin: one-liner + Releases  
- [ ] 小红书 / 抖音 profile: same avatar (`logo.png` / app icon), bio from copy bank  
- [ ] Short demo video (30s): grid + multi-display, end card tagline  

### Phase D — Product alignment

- [x] Settings About: tagline (`Snap to the line.` / `一线到位。`) + Loop credit  
- [ ] Onboarding / permissions copy stays factual; marketing surfaces stay capability-first  
- [ ] URL scheme docs lead with calm automation examples  

---

## 9. Competitive framing (internal)

| Vs | Line says |
| --- | --- |
| Rectangle / Magnet | First-class **grid**, multi-display, native open-source lineage—not a feature laundry list |
| Loop (upstream) | Personal fork with Line product direction; always credit |
| Tiling WMs | Floating window manager with strong grid; not a full tiling desktop replacement |

Public posts: **compare features, not people**.

---

## 10. Legal & trust (brand-facing)

- License: GPLv3 — state clearly on README and Releases.  
- Upstream: MrKai77/Loop — always credit.  
- Signing: free Apple Development for Accessibility stickiness; not notarized — say so.  
- Privacy: local-first; no analytics; Sparkle → GitHub only — align with `docs/PRIVACY.md`.  
- Security reports: private advisories only — never brand “bug bounty” unless real.

---

## 11. Name & trademark notes

- **Line** is a common English word — own the **mark + macOS window manager** context, not the word alone.  
- Prefer `Line for macOS` / `nnecec/Line` in SEO.  
- Do not use unofficial “official” claims beyond this repository’s Releases.

---

## 12. Quick approval checklist

Before publishing any asset or post:

1. Tagline: EN **Snap to the line.** / ZH **一线到位。**; logo is root `logo.png` only.  
2. Lead with grid · multi-display · performance · native · open source—not input methods or Accessibility.  
3. No private window titles / paths.  
4. Install path points only to this repo’s Releases.  
5. Signing / notarization language is accurate when you mention install.  
6. Loop credit if history is mentioned.  
7. EN first for engineering surfaces; ZH localized, not machine-dumped.  
3. Install path points only to this repo’s Releases.  
4. Signing / notarization language is accurate.  
5. Loop credit if history is mentioned.  
6. EN first for engineering surfaces; ZH localized, not machine-dumped.

---

*Last updated: 2026-07-21. Visual boards may be added under `assets/brand/` without changing the strategy above.*
