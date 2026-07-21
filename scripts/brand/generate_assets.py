#!/usr/bin/env python3
"""Generate Line social/brand presentation assets from the shipping logo.png.

Does NOT design a new logo. Composites repository-root logo.png only.
Palette is derived from logo.png: near-white mark (#F8F8F8) on dark neutrals.

Typography: PingFang SC (苹方) for all marketing copy — EN and ZH.
Feature lists are drawn as spaced segments (not a single middle-dot string)
to avoid uneven metrics / glyph overlap in Pillow.

Requires: Pillow (pip install pillow)
"""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parents[2]
LOGO_PATH = REPO / "logo.png"
OUT = REPO / "assets" / "brand"
OUT.mkdir(parents=True, exist_ok=True)

# Derived from logo.png: opaque mark samples quantize to ~#F8F8F8 on transparent.
PAPER = (248, 248, 248, 255)
INK = (10, 10, 10, 255)
PANEL = (22, 22, 22, 255)
MUTE = (140, 140, 140, 255)
RULE = (248, 248, 248, 40)

# Super-sample factor for cleaner type (draw large, then LANCZOS downscale).
SCALE = 2

# Separator between feature chips (ASCII, even metrics).
SEP = "  ·  "

PINGFANG_CANDIDATES = (
    # System font asset (macOS installs via Font assets)
    *sorted(Path("/System/Library/AssetsV2").glob("**/PingFang.ttc")),
    Path("/System/Library/Fonts/PingFang.ttc"),
    Path(
        "/Users/nnecec/Library/Application Support/"
        "com.electron.lark.font_workaround/PingFang.ttc"
    ),
    # Fallbacks if PingFang is unavailable
    Path("/System/Library/Fonts/Hiragino Sans GB.ttc"),
    Path("/System/Library/Fonts/STHeiti Medium.ttc"),
    Path("/System/Library/Fonts/Supplemental/Arial Unicode.ttf"),
    Path("/System/Library/Fonts/SFNS.ttf"),
    Path("/System/Library/Fonts/Helvetica.ttc"),
)

MONO_CANDIDATES = (
    Path("/System/Library/Fonts/SFNSMono.ttf"),
    Path("/System/Library/Fonts/Menlo.ttc"),
    Path("/System/Library/Fonts/Monaco.ttf"),
)

# PingFang SC face indices in standard PingFang.ttc collections
_SC_STYLE_INDEX = {
    "regular": 3,
    "medium": 7,
    "semibold": 11,
    "light": 15,
    "thin": 19,
}


def _resolve_pingfang() -> tuple[Path, dict[str, int]] | None:
    for path in PINGFANG_CANDIDATES:
        if not path.is_file():
            continue
        # Probe SC Regular
        try:
            ImageFont.truetype(str(path), 24, index=3)
            # Verify name if possible
            face = ImageFont.truetype(str(path), 24, index=3)
            name = face.getname()
            if "PingFang" in name[0] or "Hiragino" in name[0] or "Heiti" in name[0]:
                return path, dict(_SC_STYLE_INDEX)
            # Single-face TTF
            return path, {"regular": 0, "medium": 0, "semibold": 0, "light": 0, "thin": 0}
        except OSError:
            try:
                ImageFont.truetype(str(path), 24, index=0)
                return path, {"regular": 0, "medium": 0, "semibold": 0, "light": 0, "thin": 0}
            except OSError:
                continue
    return None


_FONT_PACK = _resolve_pingfang()


@lru_cache(maxsize=64)
def pf(size: int, weight: str = "regular") -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    """PingFang SC (or best available) at *logical* size — already scaled by SCALE."""
    px = max(1, int(round(size * SCALE)))
    if _FONT_PACK is None:
        return ImageFont.load_default()
    path, styles = _FONT_PACK
    index = styles.get(weight, styles.get("regular", 0))
    try:
        return ImageFont.truetype(str(path), px, index=index)
    except OSError:
        try:
            return ImageFont.truetype(str(path), px, index=0)
        except OSError:
            return ImageFont.load_default()


@lru_cache(maxsize=32)
def mono(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    px = max(1, int(round(size * SCALE)))
    for path in MONO_CANDIDATES:
        if not path.is_file():
            continue
        try:
            return ImageFont.truetype(str(path), px)
        except OSError:
            continue
    return pf(size, "regular")


def S(v: int | float) -> int:
    """Scale a layout coordinate to supersampled canvas."""
    return int(round(v * SCALE))


def load_logo() -> Image.Image:
    if not LOGO_PATH.is_file():
        raise SystemExit(f"missing shipping logo: {LOGO_PATH}")
    return Image.open(LOGO_PATH).convert("RGBA")


def place_logo(
    canvas: Image.Image,
    logo: Image.Image,
    *,
    center: tuple[int, int],
    max_side: int,
) -> None:
    """Composite logo.png; center/max_side are in *logical* (pre-SCALE) units."""
    max_side_px = S(max_side)
    cx, cy = S(center[0]), S(center[1])
    w, h = logo.size
    scale = max_side_px / max(w, h)
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    resized = logo.resize((nw, nh), Image.Resampling.LANCZOS)
    x = cx - nw // 2
    y = cy - nh // 2
    canvas.alpha_composite(resized, (x, y))


def text_size(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.ImageFont) -> tuple[int, int]:
    bbox = draw.textbbox((0, 0), text, font=font)
    return bbox[2] - bbox[0], bbox[3] - bbox[1]


def draw_text(
    draw: ImageDraw.ImageDraw,
    xy: tuple[float, float],
    text: str,
    *,
    font: ImageFont.ImageFont,
    fill: tuple[int, int, int, int],
    anchor: str | None = None,
    tracking: float = 0.0,
) -> None:
    """Draw text with optional extra letter-spacing (tracking in *logical* em-ish px).

    tracking > 0 adds space between glyphs; avoids cramped SFNS/PingFang Latin.
    """
    x, y = S(xy[0]), S(xy[1])
    if tracking == 0 or len(text) <= 1:
        draw.text((x, y), text, font=font, fill=fill, anchor=anchor)
        return

    track = tracking * SCALE
    # Measure full string with tracking for anchor adjustment
    widths: list[int] = []
    for ch in text:
        w, _ = text_size(draw, ch, font)
        widths.append(w)
    total = sum(widths) + track * (len(text) - 1)

    # Resolve start from anchor (horizontal only; vertical via anchor on first glyph baseline)
    ax = anchor or "la"
    if "m" in ax[0] if len(ax) >= 1 else False:
        # Pillow anchors: mm, lm, rm, ma, mt, mb, ...
        pass
    # Simpler: support la/lt (default left), mm (center), ra (right)
    start_x = x
    if anchor in ("mm", "ma", "mt", "mb", "ms"):
        start_x = x - total // 2
    elif anchor in ("rm", "ra", "rt", "rb", "rs"):
        start_x = x - total

    # Vertical: use anchor on each char with same y
    cursor = start_x
    char_anchor = "la"
    if anchor and len(anchor) >= 2:
        # keep vertical component
        char_anchor = "l" + anchor[1]
    for i, ch in enumerate(text):
        draw.text((cursor, y), ch, font=font, fill=fill, anchor=char_anchor)
        cursor += widths[i] + track


def draw_features(
    draw: ImageDraw.ImageDraw,
    xy: tuple[float, float],
    parts: list[str],
    *,
    font: ImageFont.ImageFont,
    fill: tuple[int, int, int, int],
    anchor: str = "la",
    sep: str = SEP,
) -> None:
    """Draw a feature list as separate words + separators for even spacing."""
    text = sep.join(parts)
    # Prefer whole-string draw with PingFang (Latin metrics OK) after supersample;
    # still measure and center properly.
    x, y = S(xy[0]), S(xy[1])
    draw.text((x, y), text, font=font, fill=fill, anchor=anchor)


def finish(im: Image.Image, path: Path) -> None:
    """Downscale supersampled canvas to logical size."""
    if SCALE != 1:
        w, h = im.size
        im = im.resize((w // SCALE, h // SCALE), Image.Resampling.LANCZOS)
    im.save(path, "PNG", optimize=True)
    print("wrote", path.relative_to(REPO))


def canvas(w: int, h: int, color: tuple[int, int, int, int] = INK) -> Image.Image:
    return Image.new("RGBA", (S(w), S(h)), color)


def make_og(logo: Image.Image) -> None:
    w, h = 1280, 640
    im = canvas(w, h, INK)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([S(40), S(40), S(w - 40), S(h - 40)], radius=S(28), fill=PANEL)
    place_logo(im, logo, center=(220, h // 2), max_side=240)

    left = 420
    # Title stack: top Y + fixed step (logical px) so bands never overlap
    y0 = 176
    d.text((S(left), S(y0)), "Line", font=pf(64, "semibold"), fill=PAPER)
    d.text((S(left), S(y0 + 92)), "Snap to the line.", font=pf(32, "regular"), fill=MUTE)
    draw_features(
        d,
        (left, y0 + 160),
        ["Grid", "multi-display", "native", "open source"],
        font=pf(20, "regular"),
        fill=MUTE,
    )
    d.text((S(left), S(y0 + 216)), "github.com/nnecec/Line", font=mono(20), fill=MUTE)
    finish(im, OUT / "og-github.png")


def make_x(logo: Image.Image) -> None:
    w, h = 1600, 900
    im = canvas(w, h, INK)
    d = ImageDraw.Draw(im)
    for i in range(0, w, 100):
        d.line([(S(i), 0), (S(i), S(h))], fill=RULE, width=max(1, SCALE // 2))
    for j in range(0, h, 100):
        d.line([(0, S(j)), (S(w), S(j))], fill=RULE, width=max(1, SCALE // 2))

    place_logo(im, logo, center=(w // 3 - 40, h // 2), max_side=280)
    left = w // 3 + 160
    # Explicit stack tops (logical px) — roomy gaps so lines never collide
    y_title = h // 2 - 120
    y_tag = y_title + 96
    y_feat = y_tag + 56
    y_url = y_feat + 48
    d.text((S(left), S(y_title)), "Line", font=pf(72, "semibold"), fill=PAPER)
    d.text((S(left), S(y_tag)), "Snap to the line.", font=pf(34, "regular"), fill=MUTE)
    draw_features(
        d,
        (left, y_feat),
        ["Grid", "multi-display", "native", "open source"],
        font=pf(20, "regular"),
        fill=MUTE,
    )
    d.text((S(left), S(y_url)), "github.com/nnecec/Line", font=mono(22), fill=MUTE)
    finish(im, OUT / "cover-x.png")


def make_xhs(logo: Image.Image) -> None:
    w, h = 1080, 1440
    im = canvas(w, h, INK)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([S(36), S(36), S(w - 36), S(h - 36)], radius=S(36), fill=PANEL)
    place_logo(im, logo, center=(w // 2, 400), max_side=320)

    # Centered stack with fixed baselines (anchor mm)
    d.text((S(w // 2), S(690)), "Line", font=pf(64, "semibold"), fill=PAPER, anchor="mm")
    d.text((S(w // 2), S(790)), "一线到位。", font=pf(44, "medium"), fill=MUTE, anchor="mm")
    draw_features(
        d,
        (w // 2, 890),
        ["网格优先", "多屏幕", "高性能", "开源"],
        font=pf(28, "regular"),
        fill=MUTE,
        anchor="mm",
        sep="  ·  ",
    )
    d.text(
        (S(w // 2), S(980)),
        "macOS 原生窗口管理",
        font=pf(24, "regular"),
        fill=MUTE,
        anchor="mm",
    )
    d.text(
        (S(w // 2), S(1280)),
        "github.com/nnecec/Line",
        font=mono(22),
        fill=MUTE,
        anchor="mm",
    )
    finish(im, OUT / "cover-xhs.png")


def make_douyin(logo: Image.Image) -> None:
    w, h = 1080, 1920
    im = canvas(w, h, INK)
    d = ImageDraw.Draw(im)
    place_logo(im, logo, center=(w // 2, int(h * 0.34)), max_side=360)

    cy0 = int(h * 0.52)
    d.text((S(w // 2), S(cy0)), "Line", font=pf(72, "semibold"), fill=PAPER, anchor="mm")
    d.text(
        (S(w // 2), S(cy0 + 90)),
        "Snap to the line.",
        font=pf(34, "regular"),
        fill=MUTE,
        anchor="mm",
    )
    d.text(
        (S(w // 2), S(cy0 + 160)),
        "一线到位。",
        font=pf(32, "medium"),
        fill=MUTE,
        anchor="mm",
    )
    draw_features(
        d,
        (w // 2, cy0 + 230),
        ["网格优先", "多屏幕", "高性能", "开源"],
        font=pf(24, "regular"),
        fill=MUTE,
        anchor="mm",
    )
    d.text(
        (S(w // 2), S(cy0 + 340)),
        "github.com/nnecec/Line",
        font=mono(22),
        fill=MUTE,
        anchor="mm",
    )
    finish(im, OUT / "cover-douyin.png")


def make_board(logo: Image.Image) -> None:
    w, h = 1920, 1080
    im = canvas(w, h, (8, 8, 8, 255))
    d = ImageDraw.Draw(im)
    gutter = 14
    cols = 3
    pw = (w - gutter * (cols + 1)) // cols
    ph = (h - gutter * 4) // 3
    titles = [
        "01 LOGO",
        "02 ON DARK",
        "03 ON PANEL",
        "04 ESSENCE",
        "05 COLOR",
        "06 TYPE",
        "07 GITHUB",
        "08 SOCIAL",
        "09 SYSTEM",
    ]
    for i, title in enumerate(titles):
        r, c = divmod(i, 3)
        x0 = gutter + c * (pw + gutter)
        y0 = gutter + r * (ph + gutter)
        d.rounded_rectangle(
            [S(x0), S(y0), S(x0 + pw), S(y0 + ph)],
            radius=S(14),
            fill=PANEL,
        )
        d.text((S(x0 + 18), S(y0 + 14)), title, font=pf(14, "regular"), fill=MUTE)
        cx, cy = x0 + pw // 2, y0 + ph // 2 + 8

        if i == 0:
            place_logo(im, logo, center=(cx, cy - 8), max_side=min(pw, ph) // 2)
            d.text(
                (S(cx), S(y0 + ph - 32)),
                "logo.png",
                font=pf(14, "regular"),
                fill=MUTE,
                anchor="mm",
            )
        elif i == 1:
            d.rounded_rectangle(
                [S(x0 + 24), S(y0 + 40), S(x0 + pw - 24), S(y0 + ph - 24)],
                radius=S(10),
                fill=INK,
            )
            place_logo(im, logo, center=(cx, cy + 4), max_side=min(pw, ph) // 2)
        elif i == 2:
            place_logo(im, logo, center=(cx, cy), max_side=min(pw, ph) // 2)
        elif i == 3:
            d.text(
                (S(cx), S(cy - 16)),
                "Snap to the line.",
                font=pf(26, "medium"),
                fill=PAPER,
                anchor="mm",
            )
            draw_features(
                d,
                (cx, cy + 32),
                ["Grid", "multi-display", "native"],
                font=pf(15, "regular"),
                fill=MUTE,
                anchor="mm",
            )
        elif i == 4:
            swatches = [
                ((10, 10, 10), "ink"),
                ((22, 22, 22), "panel"),
                ((140, 140, 140), "mute"),
                ((248, 248, 248), "mark"),
            ]
            sw = (pw - 80) // len(swatches)
            for j, (col, name) in enumerate(swatches):
                sx = x0 + 30 + j * (sw + 8)
                d.rounded_rectangle(
                    [S(sx), S(cy - 28), S(sx + sw), S(cy + 28)],
                    radius=S(6),
                    fill=col + (255,),
                )
                if col[0] > 200:
                    d.rounded_rectangle(
                        [S(sx), S(cy - 28), S(sx + sw), S(cy + 28)],
                        radius=S(6),
                        outline=(80, 80, 80, 255),
                        width=max(1, SCALE),
                    )
                d.text(
                    (S(sx + sw // 2), S(cy + 48)),
                    name,
                    font=pf(12, "regular"),
                    fill=MUTE,
                    anchor="mm",
                )
            d.text(
                (S(cx), S(y0 + ph - 28)),
                "from logo.png · #F8F8F8 mark",
                font=pf(12, "regular"),
                fill=MUTE,
                anchor="mm",
            )
        elif i == 5:
            d.text((S(cx), S(cy - 36)), "Line", font=pf(36, "semibold"), fill=PAPER, anchor="mm")
            d.text(
                (S(cx), S(cy + 12)),
                "line://half left",
                font=mono(14),
                fill=MUTE,
                anchor="mm",
            )
            d.text(
                (S(cx), S(cy + 44)),
                "PingFang SC · 苹方",
                font=pf(13, "regular"),
                fill=MUTE,
                anchor="mm",
            )
        elif i == 6:
            d.rounded_rectangle(
                [S(x0 + 50), S(cy - 48), S(x0 + pw - 50), S(cy + 48)],
                radius=S(12),
                fill=INK,
            )
            place_logo(im, logo, center=(cx - 90, cy), max_side=56)
            d.text(
                (S(cx + 36), S(cy - 14)),
                "Line vX.Y.Z",
                font=pf(20, "medium"),
                fill=PAPER,
                anchor="mm",
            )
            d.text(
                (S(cx + 36), S(cy + 20)),
                "DMG · ZIP · SHA256",
                font=pf(13, "regular"),
                fill=MUTE,
                anchor="mm",
            )
        elif i == 7:
            place_logo(im, logo, center=(cx, cy - 24), max_side=90)
            d.text(
                (S(cx), S(cy + 48)),
                "X · 小红书 · 抖音",
                font=pf(16, "regular"),
                fill=MUTE,
                anchor="mm",
            )
            d.text(
                (S(cx), S(cy + 78)),
                "github.com/nnecec/Line",
                font=mono(12),
                fill=MUTE,
                anchor="mm",
            )
        else:
            chips = ["Grid", "Multi-display", "Native", "Performance", "Open source", "line://"]
            for j, chip in enumerate(chips):
                sx = x0 + 28 + (j % 3) * ((pw - 56) // 3 + 6)
                sy = cy - 40 + (j // 3) * 48
                cw = (pw - 70) // 3
                d.rounded_rectangle(
                    [S(sx), S(sy), S(sx + cw), S(sy + 34)],
                    radius=S(8),
                    fill=INK,
                )
                d.text(
                    (S(sx + cw // 2), S(sy + 17)),
                    chip,
                    font=pf(12, "regular"),
                    fill=PAPER,
                    anchor="mm",
                )

    finish(im, OUT / "brand-board.png")


def main() -> None:
    if _FONT_PACK:
        path, styles = _FONT_PACK
        face = ImageFont.truetype(str(path), 24, index=styles.get("regular", 0))
        print(f"typeface: {face.getname()} @ {path}")
    else:
        print("typeface: default (PingFang not found)")
    logo = load_logo()
    print(f"using shipping logo {LOGO_PATH} size={logo.size}; supersample ×{SCALE}")
    make_og(logo)
    make_x(logo)
    make_xhs(logo)
    make_douyin(logo)
    make_board(logo)
    print("done →", OUT.relative_to(REPO))


if __name__ == "__main__":
    main()
