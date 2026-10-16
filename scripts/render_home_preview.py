#!/usr/bin/env python3
"""Draw the design preview of the ShiaVerse home dashboard.

This is not a screenshot: it renders the fifteen containers of the home design
with the app's own fonts, at the measurements used by
``app/lib/widgets/home_dashboard.dart`` (a 352 x 594 canvas, a 42 px rail, a
192 x 190 prayer card, five 90 x 110 collection cards, a 242 x 80 moment card,
a dial of 0.9 of its box, a 242 x 46 search bar and five 62 px panel buttons).
It is here so the layout can be reviewed — and re-rendered after a change —
without a phone in hand. The real screenshots come from the Flutter test
(``app/test/ui_layout_test.dart``, ``SHIAVERSE_PREVIEW_DIR``).

Dependencies::

    python3 -m pip install --break-system-packages Pillow arabic-reshaper python-bidi

Usage::

    python3 scripts/render_home_preview.py     # writes docs/previews/home-1-11.png
"""
from __future__ import annotations

from pathlib import Path

import arabic_reshaper
from bidi.algorithm import get_display
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs" / "previews" / "home-1-11.png"

S = 3  # supersampling
W, H = 360, 800
CANVAS_H = 610  # the dashboard's own canvas; it is centred in what is left
PAD = 6
GAP = 8
ROW_GAP = 10
RAIL_W = 42
PRAYER_H = 190
MOMENT_H = 80
SEARCH_H = 46
RIGHT_W = 90
RIGHT_CARD_H = 110
DOCK_SQUARE = 62
DOCK_PAD = 10

URDU = str(ROOT / "app/assets/fonts/JameelNooriNastaleeq.ttf")
ARABIC = str(ROOT / "app/assets/fonts/Amiri-Regular.ttf")
LATIN = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
LATIN_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

BG_TOP, BG_BOTTOM = (242, 245, 243), (223, 231, 227)
EMERALD, EMERALD_DARK = (25, 101, 76), (10, 53, 40)
PLUM, PLUM_DARK = (69, 34, 92), (38, 16, 58)
GOLD, GOLD_SOFT = (197, 154, 80), (235, 213, 168)
AMBER, AMBER_DARK = (243, 169, 60), (217, 126, 18)
MOMENT_INK = (74, 42, 5)
PAPER = (248, 244, 234)
WHITE = (246, 251, 247)
SKY_TOP, SKY_BOTTOM = (24, 44, 74), (58, 32, 74)

SECTIONS = [
    ("قرآنِ کریم", "ترجمہ و تفسیر کے ساتھ", "ک", EMERALD, (10, 53, 40)),
    ("احادیث", "ایک لاکھ کے قریب احادیث", "ح", (20, 107, 112), (7, 59, 66)),
    ("مفاتیح الجنان و صحیفہ سجادیہ", "مکمل", "د", (19, 92, 120), (8, 47, 68)),
    ("نہج البلاغہ", "خطب، خطوط اور حکمت", "ن", (35, 86, 63), (14, 46, 32)),
    ("دینی مسائل", "احکام و فتاویٰ", "ف", (74, 34, 96), (39, 16, 58)),
]
DOCK = [
    ("گھر", "⌂", PLUM),
    ("قرآن", "ک", EMERALD),
    ("احادیث", "ح", (20, 107, 112)),
    ("دعائیں", "د", (19, 92, 120)),
    ("مزید", "⋯", PLUM),
]
PRAYERS = [("فجر", "4:52"), ("ظہر", "12:04"), ("عصر", "15:14"), ("مغرب", "17:38"), ("عشاء", "19:02")]


def urdu(px: float) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(URDU, max(6, round(px * S)))


def arabic(px: float) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(ARABIC, max(6, round(px * S)))


def latin(px: float, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(LATIN_BOLD if bold else LATIN, max(6, round(px * S)))


def shaped(value: str) -> str:
    return get_display(arabic_reshaper.reshape(value))


def right(d, x, y, value, font, fill, anchor="ra"):
    d.text((x * S, y * S), shaped(value), font=font, fill=fill, anchor=anchor)


def left(d, x, y, value, font, fill, anchor="la"):
    d.text((x * S, y * S), value, font=font, fill=fill, anchor=anchor)


def vgradient(size, top, bottom, bias=0.0):
    img = Image.new("RGB", size)
    px = img.load()
    for y in range(size[1]):
        for x in range(size[0]):
            t = min(1.0, max(0.0, y / max(1, size[1] - 1) + bias))
            px[x, y] = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    return img


def card(size, radius, start, end, outline=GOLD, ow=1.2, bias=0.0):
    """A rounded card with a vertical gradient and a hairline."""
    box = (round(size[0] * S), round(size[1] * S))
    base = Image.new("RGBA", box, (0, 0, 0, 0))
    mask = Image.new("L", box, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, box[0] - 1, box[1] - 1), radius=round(radius * S), fill=255)
    base.paste(vgradient(box, start, end, bias).convert("RGBA"), (0, 0), mask)
    ImageDraw.Draw(base).rounded_rectangle(
        (0, 0, box[0] - 1, box[1] - 1),
        radius=round(radius * S),
        outline=outline,
        width=max(1, round(ow * S)),
    )
    return base


def wrap(d, value, font, max_w):
    words, lines, line = value.split(), [], ""
    for word in words:
        probe = (line + " " + word).strip()
        if d.textlength(shaped(probe), font=font) <= max_w * S or not line:
            line = probe
        else:
            lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def main() -> None:
    canvas = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 255))
    canvas.paste(vgradient((W * S, H * S), BG_TOP, BG_BOTTOM).convert("RGBA"), (0, 0))

    dock_h = DOCK_PAD * 2 + DOCK_SQUARE
    # The dashboard is one canvas, scaled as a piece and centred in the space
    # the phone has left above the panel (360 x 800 here: scale 1).
    top = round((H - dock_h - CANVAS_H) / 2)
    left_w = W - 2 * PAD - RIGHT_W - GAP      # 242
    left_x = PAD + RIGHT_W + GAP             # 104
    rail_x = left_x + left_w - RAIL_W        # 304
    card_w = left_w - RAIL_W - GAP           # 192
    block_h = CANVAS_H - 2 * PAD

    # ---- 1: the ShiaVerse rail
    rail = card((RAIL_W, PRAYER_H), 21, PLUM, PLUM_DARK)
    rl = ImageDraw.Draw(rail)
    cx, cy, r = (RAIL_W / 2) * S, 23 * S, 14 * S
    rl.ellipse((cx - r, cy - r, cx + r, cy + r), fill=PAPER, outline=GOLD, width=round(1.2 * S))
    logo = Image.open(ROOT / "app/assets/images/shiaverse_icon.png").convert("RGB").resize((int(r * 1.8), int(r * 1.8)))
    mask = Image.new("L", logo.size, 0)
    ImageDraw.Draw(mask).ellipse((0, 0, logo.size[0] - 1, logo.size[1] - 1), fill=255)
    rail.paste(logo, (round(cx - r * 0.9), round(cy - r * 0.9)), mask)
    spine = Image.new("RGBA", (RAIL_W * S, (PRAYER_H - 60) * S), (0, 0, 0, 0))
    left(ImageDraw.Draw(spine), RAIL_W / 2, (PRAYER_H - 60) / 2, "ShiaVerse", latin(14, True), GOLD_SOFT, anchor="mm")
    rail.alpha_composite(spine.rotate(-90, expand=True), (0, round(50 * S)))
    canvas.alpha_composite(rail, (rail_x * S, top * S))

    # ---- 2: the mini prayer card
    pw = card_w
    sky = Image.new("RGBA", (round(pw * S), round(PRAYER_H * S)), (0, 0, 0, 0))
    mask = Image.new("L", sky.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, sky.size[0] - 1, sky.size[1] - 1), radius=round(20 * S), fill=255)
    sky.paste(vgradient(sky.size, SKY_TOP, SKY_BOTTOM).convert("RGBA"), (0, 0), mask)
    sd = ImageDraw.Draw(sky)
    for index in range(70):
        sd.point(((index * 37 % (pw * S)), (index * 53 % (PRAYER_H * S))), fill=(255, 255, 255, 200))
    sky.alpha_composite(card((pw, PRAYER_H), 20, SKY_TOP, SKY_BOTTOM, outline=GOLD, ow=1.3))
    sd = ImageDraw.Draw(sky)
    right(sd, pw - 9, 9, "اسلام آباد", urdu(11.5), WHITE)
    sd.ellipse((round(9 * S), round(10 * S), round(23 * S), round(24 * S)), outline=(255, 255, 255, 220), width=round(1 * S))
    left(sd, pw / 2, 44, "10:30", latin(31, True), WHITE, anchor="mm")
    right(sd, pw / 2, 64, "۲۴ ربیع الاول ۱۴۴۸", urdu(10.5), (255, 225, 161), anchor="ma")
    cell = (pw - 18) / 5
    for index, (name, time) in enumerate(PRAYERS):
        x = 9 + index * cell
        active = index == 1
        colour = (255, 225, 161) if active else WHITE
        if active:
            sd.rounded_rectangle(
                (round((x + 2) * S), round(136 * S), round((x + cell - 2) * S), round((PRAYER_H - 6) * S)),
                radius=round(10 * S),
                fill=(255, 255, 255, 60),
            )
        right(sd, x + cell / 2, 139, name, urdu(9.5), colour, anchor="ma")
        left(sd, x + cell / 2, 154, time, latin(11, True), colour, anchor="ma")
        if active:
            sd.rounded_rectangle(
                (round((x + cell / 2 - 12) * S), round(170 * S), round((x + cell / 2 + 12) * S), round(180 * S)),
                radius=round(7 * S),
                fill=(255, 225, 161),
            )
            left(sd, x + cell / 2, 175, "Now", latin(7.5, True), (74, 42, 5), anchor="mm")
    canvas.alpha_composite(sky, (left_x * S, top * S))

    # ---- 8: ayah / hadith of the moment
    moment = card((left_w, MOMENT_H), 18, AMBER, AMBER_DARK, bias=-0.1)
    md = ImageDraw.Draw(moment)
    right(md, left_w - 46, 8, "أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ", arabic(12.5), MOMENT_INK)
    for index, line in enumerate(
        wrap(md, "یاد رکھو! اللہ کے ذکر ہی سے دلوں کو سکون ملتا ہے۔", urdu(11), left_w - 60)[:2]
    ):
        right(md, left_w - 46, 26 + index * 15, line, urdu(11), MOMENT_INK)
    right(md, left_w - 46, 60, "سورہ الرعد، آیت ۲۸", urdu(9), MOMENT_INK)
    tag = Image.new("RGBA", (34 * S, (MOMENT_H - 14) * S), (0, 0, 0, 0))
    td = ImageDraw.Draw(tag)
    td.rounded_rectangle(
        (0, 0, tag.size[0] - 1, tag.size[1] - 1),
        radius=round(13 * S),
        fill=(255, 255, 255, 92),
        outline=GOLD,
        width=round(1 * S),
    )
    word = Image.new("RGBA", tag.size, (0, 0, 0, 0))
    right(ImageDraw.Draw(word), 17, (MOMENT_H - 14) / 2, "آیت", urdu(11.5), MOMENT_INK, anchor="mm")
    tag.alpha_composite(word.rotate(-90, expand=True))
    moment.alpha_composite(tag, (round((left_w - 42) * S), round(7 * S)))
    md.rounded_rectangle(
        (round(8 * S), round((MOMENT_H / 2 - 17) * S), round(34 * S), round((MOMENT_H / 2 + 17) * S)),
        radius=round(12 * S),
        fill=(255, 255, 255, 90),
        outline=GOLD,
        width=round(1 * S),
    )
    left(md, 21, MOMENT_H / 2, "‹", latin(20, True), MOMENT_INK, anchor="mm")
    canvas.alpha_composite(moment, (left_x * S, (top + PRAYER_H + ROW_GAP) * S))

    # ---- 9: the tasbeeh dial
    dial_top = top + PRAYER_H + ROW_GAP + MOMENT_H + ROW_GAP
    dial_box = block_h - (PRAYER_H + ROW_GAP + MOMENT_H + ROW_GAP + SEARCH_H + ROW_GAP)
    diameter = round(min(left_w, dial_box) * 0.9)
    radius = diameter / 2
    dial = Image.new("RGBA", (diameter * S, diameter * S), (0, 0, 0, 0))
    dd = ImageDraw.Draw(dial)
    for step in range(diameter * S, 0, -1):
        t = step / (diameter * S)
        shade = round(243 - 60 * (1 - t) ** 0.5)
        dd.ellipse(
            (radius * S - step, radius * S - step, radius * S + step, radius * S + step),
            fill=(shade, shade + 3, shade + 5, 255),
        )
    circular = Image.new("L", dial.size, 0)
    ImageDraw.Draw(circular).ellipse((0, 0, diameter * S - 1, diameter * S - 1), fill=255)
    dial.putalpha(Image.composite(dial.getchannel("A"), Image.new("L", dial.size, 0), circular))
    dd = ImageDraw.Draw(dial)
    dd.ellipse((0, 0, diameter * S - 1, diameter * S - 1), outline=GOLD, width=round(1.4 * S))
    for step in (0.42, 0.58, 0.74, 0.88, 0.95):
        dd.ellipse(
            (
                radius * S - radius * step * S,
                radius * S - radius * step * S,
                radius * S + radius * step * S,
                radius * S + radius * step * S,
            ),
            outline=(255, 255, 255, 130),
            width=max(1, round(0.8 * S)),
        )
    centre = radius * S
    dd.arc(
        (centre - radius * 0.68 * S, centre - radius * 0.68 * S, centre + radius * 0.68 * S, centre + radius * 0.68 * S),
        -90,
        120,
        fill=GOLD,
        width=round(3.2 * S),
    )
    right(dd, diameter / 2, diameter * 0.085, "سُبْحَانَ اللّٰهِ", arabic(14), (60, 68, 72), anchor="ma")
    eb = diameter * 0.07
    dd.ellipse(
        (round((diameter * 0.06) * S), round((diameter * 0.06) * S), round((diameter * 0.06 + eb * 2) * S), round((diameter * 0.06 + eb * 2) * S)),
        fill=PAPER,
        outline=GOLD,
        width=round(1.2 * S),
    )
    left(dd, diameter * 0.06 + eb, diameter * 0.06 + eb, "⤢", latin(12, True), (60, 68, 72), anchor="mm")
    bead = diameter * 0.46
    glow = Image.new("RGBA", dial.size, (0, 0, 0, 0))
    left(ImageDraw.Draw(glow), diameter / 2, diameter / 2, "33", latin(bead * 0.42, True), (255, 255, 255, 255), anchor="mm")
    dial.alpha_composite(glow.filter(ImageFilter.GaussianBlur(round(4 * S))))
    dd.ellipse(
        (centre - bead * S / 2, centre - bead * S / 2, centre + bead * S / 2, centre + bead * S / 2),
        fill=(49, 32, 78),
        outline=GOLD,
        width=round(1.6 * S),
    )
    left(dd, diameter / 2, diameter / 2, "33", latin(bead * 0.42, True), (244, 248, 255), anchor="mm")
    side = diameter * 0.19
    for offset, glyph, filled in ((-0.36, "+", True), (0.36, "↻", False)):
        bx = diameter / 2 + diameter * offset
        dd.ellipse(
            ((bx - side / 2) * S, (radius - side / 2) * S, (bx + side / 2) * S, (radius + side / 2) * S),
            fill=EMERALD if filled else PAPER,
            outline=GOLD,
            width=round(1.4 * S),
        )
        left(
            dd,
            bx,
            radius,
            glyph,
            latin(side * 0.5, True),
            WHITE if filled else (60, 68, 72),
            anchor="mm",
        )
    right(dd, diameter / 2, radius + bead / 2 + 9, "آج: 140  •  / 33", urdu(10.5), (78, 86, 90), anchor="ma")
    canvas.alpha_composite(dial, (round((left_x + left_w / 2) * S - radius * S), round(dial_top * S + dial_box * S / 2 - radius * S)))

    # ---- 10: the search bar
    search_top = top + block_h - SEARCH_H
    search = card((left_w, SEARCH_H), SEARCH_H / 2, (30, 122, 94), (14, 59, 52))
    sl = ImageDraw.Draw(search)
    sl.rounded_rectangle(
        (round(4 * S), round(4 * S), round((left_w - 4) * S), round((SEARCH_H - 4) * S)),
        radius=round((SEARCH_H - 8) / 2 * S),
        fill=PAPER,
    )
    sl.ellipse(
        (round((left_w - SEARCH_H + 5) * S), round(5 * S), round((left_w - 5) * S), round((SEARCH_H - 5) * S)),
        fill=GOLD,
        outline=(255, 255, 255, 200),
        width=round(1 * S),
    )
    left(sl, left_w - SEARCH_H / 2, SEARCH_H / 2, "⌕", latin(17, True), (58, 39, 8), anchor="mm")
    right(sl, left_w - 14, SEARCH_H / 2 + 1, "پوری لائبریری میں تلاش کریں…", urdu(11.5), (110, 106, 92), anchor="rm")
    canvas.alpha_composite(search, (left_x * S, search_top * S))

    # ---- 3-7: the five collections
    x0 = PAD
    for index, (title, slogan, glyph, start, end) in enumerate(SECTIONS):
        y = top + index * (RIGHT_CARD_H + GAP)
        section = card((RIGHT_W, RIGHT_CARD_H), 18, start, end, bias=-0.05)
        sd = ImageDraw.Draw(section)
        sd.rounded_rectangle(
            (round((RIGHT_W - 30) * S), round(6 * S), round((RIGHT_W - 6) * S), round(30 * S)),
            radius=round(8 * S),
            fill=(255, 255, 255, 40),
            outline=GOLD_SOFT,
            width=round(1 * S),
        )
        right(sd, RIGHT_W - 12, 18, glyph, urdu(12), GOLD_SOFT, anchor="mm")
        left(sd, 8, 20, "‹", latin(12, True), (255, 255, 255, 190), anchor="mm")
        y_text = 36
        for line in wrap(sd, title, urdu(12.5), RIGHT_W - 16)[:2]:
            right(sd, RIGHT_W - 8, y_text, line, urdu(12.5), WHITE)
            y_text += 16
        for line in wrap(sd, slogan, urdu(9.5), RIGHT_W - 16)[:2]:
            right(sd, RIGHT_W - 8, y_text + 2, line, urdu(9.5), GOLD_SOFT)
            y_text += 13
        canvas.alpha_composite(section, (x0 * S, y * S))

    # ---- 11-15: the bottom panel
    panel = Image.new("RGBA", (W * S, dock_h * S), (0, 0, 0, 0))
    pd = ImageDraw.Draw(panel)
    pd.rounded_rectangle((0, 0, W * S - 1, dock_h * S * 2), radius=round(24 * S), fill=(8, 10, 10, 255))
    canvas.alpha_composite(panel, (0, (H - dock_h) * S))
    slot = W / 5
    for index, (label, glyph, colour) in enumerate(DOCK):
        bx = index * slot + (slot - DOCK_SQUARE) / 2
        square = card((DOCK_SQUARE, DOCK_SQUARE), 20, tuple(min(255, c + 18) for c in colour), tuple(max(0, c - 26) for c in colour))
        sd = ImageDraw.Draw(square)
        left(sd, DOCK_SQUARE / 2, DOCK_SQUARE * 0.34, glyph, latin(20, True), WHITE, anchor="mm")
        right(sd, DOCK_SQUARE / 2, DOCK_SQUARE * 0.66, label, urdu(11), WHITE, anchor="ma")
        canvas.alpha_composite(square, (round(bx * S), round((H - dock_h + DOCK_PAD) * S)))

    out = canvas.convert("RGB").resize((W * 2, H * 2), Image.LANCZOS)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    out.save(OUTPUT)
    print(f"wrote {OUTPUT.relative_to(ROOT)} ({out.size[0]}x{out.size[1]})")


if __name__ == "__main__":
    main()
