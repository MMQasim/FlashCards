#!/usr/bin/env python3
"""Generate the Android launcher icons and the Play Store listing icon.

    python3 tools/generate_icons.py

Checked in as a script rather than hand-drawn assets so the icon can be
regenerated at any density after a design change. The motif is a stack of two
flashcards with a "D" on the front one, drawn on the app's brand colour.

Adaptive icons (API 26+) get a separate background and foreground; the
foreground keeps everything inside the inner 66% safe zone, because launchers
mask and animate the outer area. Pre-26 devices get a single pre-masked bitmap.
"""

from __future__ import annotations

import sqlite3
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:  # pragma: no cover
    sys.exit("Pillow is required: pip install Pillow")

REPO_ROOT = Path(__file__).resolve().parent.parent
RES = REPO_ROOT / "android" / "app" / "src" / "main" / "res"

BRAND = (63, 91, 139, 255)        # AppTheme.seed
BRAND_DARK = (47, 69, 107, 255)
CARD_FRONT = (255, 255, 255, 255)
CARD_BACK = (255, 255, 255, 125)

# Launcher icon densities: (directory suffix, legacy px, adaptive px).
# Legacy icons are 48dp, adaptive layers 108dp.
DENSITIES = [
    ("mdpi", 48, 108),
    ("hdpi", 72, 162),
    ("xhdpi", 96, 216),
    ("xxhdpi", 144, 324),
    ("xxxhdpi", 192, 432),
]

FONT_CANDIDATES = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
]


def load_font(size: int) -> ImageFont.FreeTypeFont:
    for candidate in FONT_CANDIDATES:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size)
    raise SystemExit(
        "No bold sans font found. Install fonts-dejavu-core or edit FONT_CANDIDATES."
    )


def draw_cards(img: Image.Image, scale: float, letter: str = "D") -> None:
    """Draw the card-stack motif centred in [img], sized by [scale] (0..1).

    [scale] is the fraction of the canvas the motif occupies, which is how the
    adaptive safe zone is respected: the foreground layer passes a small value.
    The rear card is drawn on its own layer and rotated, so the two read as a
    stack rather than merging into one silhouette.
    """
    size = img.size[0]
    motif = size * scale
    cx = cy = size / 2

    card_w = motif * 0.74
    card_h = motif * 0.94
    radius = motif * 0.10

    front_box = [cx - card_w / 2, cy - card_h / 2, cx + card_w / 2, cy + card_h / 2]

    # Rear card: same geometry, rotated and nudged, composited underneath.
    # Supersampled 4x so the rotated edges stay smooth at small sizes.
    ss = 4
    back_layer = Image.new("RGBA", (size * ss, size * ss), (0, 0, 0, 0))
    ImageDraw.Draw(back_layer).rounded_rectangle(
        [v * ss for v in front_box],
        radius=radius * ss,
        fill=CARD_BACK,
    )
    back_layer = back_layer.rotate(
        -11, resample=Image.BICUBIC, center=(cx * ss, cy * ss)
    )
    back_layer = back_layer.resize((size, size), Image.LANCZOS)
    img.alpha_composite(back_layer)

    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle(front_box, radius=radius, fill=CARD_FRONT)

    # The letter, optically centred on the front card.
    font = load_font(max(8, int(card_h * 0.60)))
    box = draw.textbbox((0, 0), letter, font=font)
    fx = cx - (box[2] - box[0]) / 2 - box[0]
    fy = cy - (box[3] - box[1]) / 2 - box[1]
    draw.text((fx, fy), letter, font=font, fill=BRAND_DARK)


def legacy_icon(px: int) -> Image.Image:
    """Pre-API-26 icon: brand background, rounded corners, motif on top."""
    img = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle([0, 0, px - 1, px - 1], radius=px * 0.22, fill=BRAND)
    draw_cards(img, scale=0.58)
    return img


def adaptive_foreground(px: int) -> Image.Image:
    """Foreground layer: transparent, motif inside the 66% safe zone."""
    img = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    # 0.42 of the full 108dp canvas sits comfortably inside the 72dp safe zone.
    draw_cards(img, scale=0.42)
    return img


def fit_font(draw, text: str, max_width: int, start_size: int) -> ImageFont.FreeTypeFont:
    """Largest font at or below [start_size] whose [text] fits [max_width].

    Hardcoded point sizes silently overflow as soon as the wording changes, so
    the banner measures instead of assuming.
    """
    size = start_size
    while size > 8:
        font = load_font(size)
        box = draw.textbbox((0, 0), text, font=font)
        if box[2] - box[0] <= max_width:
            return font
        size -= 2
    return load_font(8)


def card_count() -> int:
    """Read the shipped card total, so the banner cannot drift from the app."""
    db = REPO_ROOT / "assets" / "content" / "content.db"
    with sqlite3.connect(f"file:{db}?mode=ro", uri=True) as con:
        return con.execute("SELECT SUM(card_count) FROM deck").fetchone()[0]


def feature_graphic() -> Image.Image:
    """The 1024x500 banner Google Play shows at the top of the listing.

    Play crops and scales this across surfaces, so everything meaningful stays
    well inside the edges and nothing relies on the exact aspect ratio.
    """
    w, h = 1024, 500
    margin = 64
    img = Image.new("RGBA", (w, h), BRAND)
    draw = ImageDraw.Draw(img)

    # A soft diagonal wash stops the flat brand colour looking like a
    # placeholder, without competing with the text.
    wash = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(wash).polygon(
        [(0, h), (w * 0.62, 0), (w, 0), (w, h)], fill=(255, 255, 255, 14)
    )
    img.alpha_composite(wash)

    # Card motif on the left, drawn on a square canvas and pasted.
    motif_size = 300
    motif = Image.new("RGBA", (motif_size, motif_size), (0, 0, 0, 0))
    draw_cards(motif, scale=0.88)
    img.alpha_composite(motif, (margin, (h - motif_size) // 2))

    text_x = margin + motif_size + 52
    avail = w - text_x - margin

    title = "DeutschCards"
    tagline = "Learn German offline"
    detail = f"{card_count():,} cards  ·  spaced repetition  ·  audio"

    title_font = fit_font(draw, title, avail, 76)
    tag_font = fit_font(draw, tagline, avail, 34)
    detail_font = fit_font(draw, detail, avail, 26)

    # Stack the three lines and centre the block vertically.
    def height_of(text, font):
        box = draw.textbbox((0, 0), text, font=font)
        return box[3] - box[1]

    gap_a, gap_b = 20, 14
    block = (height_of(title, title_font) + gap_a
             + height_of(tagline, tag_font) + gap_b
             + height_of(detail, detail_font))
    y = (h - block) / 2

    for text, font, fill, gap in (
        (title, title_font, CARD_FRONT, gap_a),
        (tagline, tag_font, (255, 255, 255, 228), gap_b),
        (detail, detail_font, (255, 255, 255, 170), 0),
    ):
        box = draw.textbbox((0, 0), text, font=font)
        draw.text((text_x - box[0], y - box[1]), text, font=font, fill=fill)
        y += (box[3] - box[1]) + gap

    return img


def write(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "PNG", optimize=True)
    print(f"  {path.relative_to(REPO_ROOT)}  {img.size[0]}px")


def main() -> int:
    print("Launcher icons:")
    for suffix, legacy_px, adaptive_px in DENSITIES:
        folder = RES / f"mipmap-{suffix}"
        write(legacy_icon(legacy_px), folder / "ic_launcher.png")
        write(adaptive_foreground(adaptive_px), folder / "ic_launcher_foreground.png")

    # Adaptive icon descriptors.
    anydpi = RES / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    adaptive_xml = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_foreground" />\n'
        "</adaptive-icon>\n"
    )
    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        (anydpi / name).write_text(adaptive_xml, encoding="utf-8")
        print(f"  {(anydpi / name).relative_to(REPO_ROOT)}")

    colors = RES / "values" / "ic_launcher_background.xml"
    colors.parent.mkdir(parents=True, exist_ok=True)
    hex_brand = "#{:02X}{:02X}{:02X}".format(*BRAND[:3])
    colors.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<resources>\n"
        f'    <color name="ic_launcher_background">{hex_brand}</color>\n'
        "</resources>\n",
        encoding="utf-8",
    )
    print(f"  {colors.relative_to(REPO_ROOT)}")

    # Play Console requires a 512x512 32-bit PNG for the store listing.
    print("Play Store listing icon:")
    store = REPO_ROOT / "store" / "icon-512.png"
    write(legacy_icon(512), store)

    # A 1024px square is handy for press shots and other store surfaces.
    write(legacy_icon(1024), REPO_ROOT / "store" / "icon-1024.png")

    # Play Console requires a 1024x500 feature graphic for the listing.
    write(feature_graphic(), REPO_ROOT / "store" / "feature-graphic-1024x500.png")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
