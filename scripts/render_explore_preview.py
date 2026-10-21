#!/usr/bin/env python3
"""Draw the design preview of the **Xplore** lens plate.

Not a screenshot: it paints the camera-lens page at the same fractions the
Flutter screen uses (``app/lib/screens/explore_screen.dart``) — five amber
lenses climbing the brushed-metal body, the red encyclopaedia plate hanging off
the left edge, and the red radial-menu plate in the bottom-right corner — so
the layout can be reviewed, and re-rendered, without a phone in hand.

Dependencies::

    python3 -m pip install --break-system-packages Pillow arabic-reshaper python-bidi

Usage::

    python3 scripts/render_explore_preview.py     # writes docs/previews/explore.png
"""
from __future__ import annotations

import math
from pathlib import Path

import arabic_reshaper
from bidi.algorithm import get_display
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs" / "previews" / "explore.png"
# Amiri renders through Pillow on a machine without libraqm; the nastaleeq face
# bundled with the app does not, so the preview uses the app's second font.
URDU_FONT = ROOT / "app" / "assets" / "fonts" / "Amiri-Regular.ttf"
LATIN_FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

S = 2  # supersampling
W, H = 390, 844
SAFE_TOP = 44
FIELD_H = H - SAFE_TOP
LENS = min(W * 0.40, FIELD_H * 0.20)


def urdu(text: str) -> str:
    return get_display(arabic_reshaper.reshape(text))


def urdu_font(size: float) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(URDU_FONT), max(6, int(size * S)))


def latin_font(size: float) -> ImageFont.FreeTypeFont:
    try:
        return ImageFont.truetype(LATIN_FONT, max(6, int(size * S)))
    except OSError:  # pragma: no cover - only the Latin captions use this
        return urdu_font(size)


def centred(draw: ImageDraw.ImageDraw, xy, text, face, fill) -> None:
    left, top, right, bottom = draw.textbbox((0, 0), text, font=face)
    draw.text(
        (xy[0] - (right + left) / 2, xy[1] - (bottom + top) / 2),
        text,
        font=face,
        fill=fill,
    )


def radial(diameter: int, stops) -> Image.Image:
    """A radial gradient disc (transparent outside the circle)."""
    radius = diameter / 2
    image = Image.new("RGBA", (diameter, diameter), (0, 0, 0, 0))
    pixels = image.load()
    for y in range(diameter):
        for x in range(diameter):
            dx = (x - radius) / radius
            dy = (y - radius) / radius
            r = math.hypot(dx, dy)
            if r > 1:
                continue
            for index in range(len(stops) - 1):
                start, first = stops[index]
                stop, second = stops[index + 1]
                if start <= r <= stop:
                    span = (stop - start) or 1
                    f = (r - start) / span
                    pixels[x, y] = tuple(
                        int(first[channel] + (second[channel] - first[channel]) * f)
                        for channel in range(3)
                    ) + (255,)
                    break
    return image


def wedge(draw: ImageDraw.ImageDraw, origin, scale: float, flip: bool) -> None:
    """The hatched graticule triangle that sits between the lenses."""
    x, y = origin
    tip = (x - scale if flip else x + scale, y)
    corner = (x, y + scale * 0.62)
    draw.line((x, y, *tip), fill=(195, 205, 211, 26), width=S)
    draw.line((*tip, *corner), fill=(195, 205, 211, 26), width=S)
    draw.line((*corner, x, y), fill=(195, 205, 211, 26), width=S)
    for i in range(1, 6):
        f = i / 6
        draw.line(
            (x + (tip[0] - x) * f, y, x + (corner[0] - x) * f, y + (corner[1] - y) * f),
            fill=(195, 205, 211, 22),
            width=S,
        )


def hatch(canvas: Image.Image, box, tone=(255, 255, 255, 22)) -> None:
    left, top, right, bottom = box
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for offset in range(int(left - (bottom - top)), int(right), 8 * S):
        draw.line((offset, bottom, offset + (bottom - top), top), fill=tone, width=S)
    mask = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=26 * S, fill=255)
    canvas.alpha_composite(Image.composite(layer, Image.new("RGBA", canvas.size, (0, 0, 0, 0)), mask))


def lens(canvas: Image.Image, centre, diameter: float, number: int, title: str,
         subtitle: str, accent) -> None:
    draw = ImageDraw.Draw(canvas)
    cx, cy = centre[0] * S, centre[1] * S
    r = diameter * S / 2
    glass_d = diameter * 0.74 * S
    disc_d = diameter * 0.55 * S

    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse(
        (cx - r * 0.94, cy - r * 0.9 + 6 * S, cx + r * 0.94, cy + r * 0.9 + 9 * S),
        fill=(0, 0, 0, 110),
    )
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(7 * S)))

    barrel = radial(
        int(diameter * S),
        [(0.0, (116, 128, 137)), (0.72, (62, 74, 81)), (1.0, (20, 27, 33))],
    )
    canvas.alpha_composite(barrel, (int(cx - r), int(cy - r)))
    for i in range(120):
        a = i / 120 * math.tau
        draw.line(
            (cx + math.cos(a) * r * 0.942, cy + math.sin(a) * r * 0.942,
             cx + math.cos(a) * r * 0.996, cy + math.sin(a) * r * 0.996),
            fill=(190, 201, 207, 55), width=S,
        )

    glass = radial(
        int(glass_d),
        [(0.0, (233, 162, 90)), (0.32, (198, 116, 36)), (0.58, (110, 58, 16)),
         (0.82, (36, 17, 9)), (1.0, (10, 13, 15))],
    )
    canvas.alpha_composite(glass, (int(cx - glass_d / 2), int(cy - glass_d / 2)))
    for i in range(5):
        rr = glass_d / 2 * (0.30 + i * 0.083)
        draw.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), outline=(255, 225, 190, 60), width=S)
    draw.arc(
        (cx - glass_d * .45, cy - glass_d * .45, cx + glass_d * .45, cy + glass_d * .45),
        200, 290, fill=(255, 227, 190, 130), width=3 * S,
    )

    disc = radial(int(disc_d), [(0.0, (34, 41, 45)), (0.7, (11, 14, 16)), (1.0, (5, 7, 8))])
    canvas.alpha_composite(disc, (int(cx - disc_d / 2), int(cy - disc_d / 2)))
    draw.ellipse(
        (cx - disc_d / 2, cy - disc_d / 2, cx + disc_d / 2, cy + disc_d / 2),
        outline=accent + (130,), width=S + 1,
    )

    lines = title.split("\n")
    line_height = diameter * 0.105 * 1.30 * S
    start = cy - line_height * (len(lines) - 1) / 2 - diameter * 0.03 * S
    for index, line in enumerate(lines):
        centred(draw, (cx, start + index * line_height), urdu(line),
                urdu_font(diameter * 0.105), (255, 255, 255))
    # The Dart lens draws the subtitle only when the title fits on one line.
    if subtitle and diameter > 96 and len(lines) == 1:
        centred(draw, (cx, cy + disc_d * 0.28), urdu(subtitle),
                urdu_font(diameter * 0.070), (221, 204, 194))

    badge = latin_font(diameter * 0.085)
    bbox = draw.textbbox((0, 0), str(number), font=badge)
    bw, bh = bbox[2] - bbox[0] + 12 * S, bbox[3] - bbox[1] + 8 * S
    top = cy - r + diameter * 0.055 * S
    draw.rounded_rectangle(
        (cx - bw / 2, top, cx + bw / 2, top + bh), radius=bh / 2,
        fill=(18, 26, 32, 200), outline=(217, 195, 166, 120), width=S,
    )
    centred(draw, (cx, top + bh / 2), str(number), badge, (231, 216, 196))


def red_plate(canvas: Image.Image, box, title: str, subtitle: str, tint) -> None:
    draw = ImageDraw.Draw(canvas)
    left, top, right, bottom = box
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(box, radius=26 * S, fill=tint + (255,))
    canvas.alpha_composite(layer)
    hatch(canvas, box)
    draw.rounded_rectangle(box, radius=26 * S, outline=(255, 162, 154, 170), width=S + 1)
    width = right - left
    centred(draw, ((left + right) / 2, top + (bottom - top) * 0.40), urdu(title),
            urdu_font(width / S * 0.092), (255, 255, 255))
    if subtitle:
        centred(draw, ((left + right) / 2, top + (bottom - top) * 0.72), urdu(subtitle),
                urdu_font(width / S * 0.072), (255, 217, 201))


def main() -> int:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    canvas = Image.new("RGBA", (W * S, H * S), (11, 18, 24, 255))
    draw = ImageDraw.Draw(canvas)

    for y in range(H * S):
        f = y / (H * S)
        draw.line((0, y, W * S, y), fill=(int(60 - 50 * f), int(72 - 55 * f), int(80 - 58 * f), 255))
    for x in range(0, W * S, 3):
        draw.line((x, 0, x, H * S), fill=(255, 255, 255, 5))

    seam = (174, 185, 191, 30)
    rect = ((-20 * S, 50 * S), (228 * S, -30 * S), (W * S + 20, 130 * S),
            (W * S - 8 * S, H * S - 25 * S), (164 * S, H * S + 25), (-18 * S, H * S - 118 * S))
    draw.polygon(rect, outline=seam, width=S + 1)
    draw.line((-18 * S, 300 * S, 172 * S, 330 * S, 118 * S, 610 * S, 24 * S, H * S - 30), fill=seam, width=S + 1)

    wedge(draw, (196 * S, 88 * S), 66 * S, False)
    wedge(draw, (300 * S, 232 * S), 50 * S, True)
    wedge(draw, (40 * S, 268 * S), 46 * S, True)
    wedge(draw, (58 * S, 546 * S), 54 * S, False)
    wedge(draw, (250 * S, 690 * S), 46 * S, True)

    def at(x: float, y: float):
        return (x * W, SAFE_TOP + y * FIELD_H)

    lens(canvas, at(0.20, 0.155), LENS, 1, "تسبیح", "تسبیح و ذکر", (233, 160, 90))
    lens(canvas, at(0.505, 0.335), LENS * 1.08, 2, "نماز", "اوقات و قرات", (111, 189, 184))
    lens(canvas, at(0.795, 0.505), LENS * 0.94, 3, "چاند کی\nرویت", "رویتِ ہلال", (181, 167, 236))
    lens(canvas, at(0.515, 0.675), LENS, 4, "اسلامی\nتقویم", "ہجری تاریخیں", (127, 199, 167))
    lens(canvas, at(0.215, 0.838), LENS * 0.88, 5, "Xplore\nXtra", "روزانہ مطالعہ", (235, 192, 107))

    plate = LENS * 0.92
    red_plate(
        canvas,
        (-plate * 0.16 * S, (SAFE_TOP + FIELD_H * 0.435 - plate * 0.44) * S,
         ((-plate * 0.16) + plate) * S, (SAFE_TOP + FIELD_H * 0.435 + plate * 0.48) * S),
        "اثنا عشری\nانسائکلوپیڈیا", "ائمہ، عقائد، تاریخ", (126, 39, 49),
    )

    # bottom-right launch plate, with the round radial-menu button
    plate_w, plate_h = LENS * 1.02, LENS * 0.78
    left = W - plate_w + LENS * 0.12
    top = SAFE_TOP + FIELD_H - plate_h - max(4.0, FIELD_H * 0.012)
    box = (left * S, top * S, (W + 30) * S, (H + 30) * S)
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(box, radius=28 * S, fill=(150, 41, 53, 255))
    canvas.alpha_composite(layer)
    hatch(canvas, box)
    draw.rounded_rectangle(box, radius=28 * S, outline=(255, 162, 154, 170), width=S + 1)

    button = min(66.0, W * 0.17)
    bx, by = (left + plate_w * 0.56) * S, (top + plate_h * 0.40) * S
    canvas.alpha_composite(
        radial(int(button * S), [(0.0, (95, 208, 166)), (0.62, (27, 107, 82)), (1.0, (11, 45, 35))]),
        (int(bx - button * S / 2), int(by - button * S / 2)),
    )
    draw.ellipse(
        (bx - button * S / 2, by - button * S / 2, bx + button * S / 2, by + button * S / 2),
        outline=(217, 255, 239, 220), width=S + 1,
    )
    for row in range(3):
        for col in range(3):
            dot = 3.6 * S
            x = bx + (col - 1) * 11 * S
            y = by + (row - 1) * 11 * S
            draw.rounded_rectangle((x - dot / 2, y - dot / 2, x + dot / 2, y + dot / 2),
                                   radius=dot / 2, fill=(242, 255, 249, 255))
    centred(draw, (bx, (top + plate_h * 0.72) * S), urdu("Radial menu"),
            latin_font(11.0), (255, 227, 214))

    # brand plate
    brand = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(brand).polygon(
        ((W * S - 156 * S, 0), (W * S, 0), (W * S, 74 * S), (W * S - 120 * S, 74 * S)),
        fill=(170, 43, 53, 255),
    )
    canvas.alpha_composite(brand)
    centred(draw, (W * S - 66 * S, 26 * S), "Xplore", latin_font(21), (255, 255, 255))
    centred(draw, (W * S - 66 * S, 52 * S), "by ShiaVerse", latin_font(10.5), (255, 255, 255, 205))

    # back button
    draw.ellipse((8 * S, 8 * S, 48 * S, 48 * S), fill=(255, 255, 255, 18),
                 outline=(201, 212, 218, 130), width=S + 1)
    draw.line((22 * S, 28 * S, 35 * S, 28 * S), fill=(255, 255, 255), width=2 * S)
    draw.line((29 * S, 22 * S, 35 * S, 28 * S), fill=(255, 255, 255), width=2 * S)
    draw.line((29 * S, 34 * S, 35 * S, 28 * S), fill=(255, 255, 255), width=2 * S)

    canvas.resize((W, H), Image.LANCZOS).convert("RGB").save(OUTPUT)
    print(f"wrote {OUTPUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
