# Release notes template

Paste into the GitHub Release body (English default). Optional Chinese block at the end for CN channels.

```markdown
## Line {{version}}

**Snap to the line.**

### Highlights

- …

### Changes

- …

### Install

Official packages (this repository only):

- `Line-{{version}}.dmg`
- `Line-{{version}}.zip`
- `SHA256SUMS.txt`

These builds use a free **Apple Development** signature so Accessibility permission can stick.
They are **not** Developer ID signed and **not** notarized.

1. Download from this Release.
2. Right-click the app → **Open**.
3. System Settings → Privacy & Security → **Accessibility** → enable Line.

### Updates

In-app **Check for Updates** uses Sparkle and [`appcast.xml`](https://github.com/nnecec/Line/blob/main/appcast.xml) on `main`.
The appcast PR for this version must be merged before the app reports the new build.

### Privacy

Line does not require an account and does not include product analytics. Window management stays on your Mac.

---

### 中文摘要（可选）

**一线到位。**

- …
- 安装：仅从本仓库 Releases 下载 → 右键打开 → 开启辅助功能。
- 非 Developer ID、未公证；Sparkle 更新需 appcast PR 合并后生效。
```

Brand voice: [docs/BRAND.md](../docs/BRAND.md). Process: [docs/RELEASES.md](RELEASES.md).
