# Line media kit

English is the default. Chinese copy is provided for CN platforms.

## Logo (shipping only)

| File | Use |
| --- | --- |
| [`../../logo.png`](../../logo.png) | **Only** official mark (1000×1000, transparent, near-white) |
| App icon / menu bar sets | Xcode only — do not invent parallel marks |

**Clear space:** ≥ 25% of mark height.  
**On dark:** use `logo.png` as-is (light mark).  
**On light:** prefer dark canvas for marketing; if a light surface is required, use a carefully inverted export only after design review — do not redraw the symbol.

Do **not** generate alternate logos, monograms, or “concept” icons for social kits.

## Colors (from `logo.png`)

Sampled mark fill is approximately **`#F8F8F8`**. Marketing is monochrome around that mark.

| Name | Hex | Role |
| --- | --- | --- |
| Mark / paper | `#F8F8F8` | Logo + primary type on dark |
| Ink | `#0A0A0A` | Social / deck background |
| Panel | `#161616` | Cards, inset panels |
| Mute | `#8C8C8C` | Secondary labels |

No cyan, coral, or gradient brand accents in marketing.

## Tagline

- **EN:** Snap to the line.  
- **ZH:** 一线到位。

## Positioning (marketing lead)

Emphasize **capabilities**, not input methods or permission requirements:

- First-class **Grid**
- **Multi-display**
- **High performance**
- **Native macOS**
- **Open source**

## Boilerplate

**EN (short)**  
Line is a native macOS window manager with first-class grid layout, multi-display support, and high performance. Open source.

**EN (credit)**  
Line is a personal fork of [MrKai77/Loop](https://github.com/MrKai77/Loop).

**ZH (short)**  
Line 是一款 macOS 原生窗口管理器：网格优先、多屏幕、高性能、开源。

**ZH (credit)**  
Line 是 [MrKai77/Loop](https://github.com/MrKai77/Loop) 的个人维护分支。

## Download

Only: https://github.com/nnecec/Line/releases  

## Do / don’t

| Do | Don’t |
| --- | --- |
| Lead with grid / multi-display / native / open source | Lead with “keyboard, mouse” or “Accessibility required” |
| Use official Releases assets | Redistribute unsigned mystery builds as “official” |
| Composite root `logo.png` | Redesign the logo for posts |
| Redact window titles in demos | Show personal documents |
| Put install honesty in install sections | Make notarization / Accessibility the hero message |
| Credit Loop when telling origin | Erase upstream history |

## Social sizes

| File | Size | Platform |
| --- | --- | --- |
| `og-github.png` | 1280×640 | GitHub Open Graph |
| `cover-x.png` | 1600×900 | X |
| `cover-xhs.png` | 1080×1440 | 小红书 |
| `cover-douyin.png` | 1080×1920 | 抖音 |
| `brand-board.png` | 1920×1080 | Identity overview |

Regenerate (composites `logo.png` only):

```bash
python3 scripts/brand/generate_assets.py
```
