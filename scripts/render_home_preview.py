#!/usr/bin/env python3
"""Draw the design preview of the ShiaVerse home screen.

This is not a screenshot: it renders the top of the home screen with the app's
own fonts and dark-theme colours, at the measurements used by
``app/lib/screens/library_screen.dart``, ``app/lib/widgets/last_seen_bar.dart``
and ``app/lib/widgets/home_utilities.dart`` (a 54 dp last-seen strip, a 112 dp
prayer banner, a 62 dp utility row, 18/22 px radii, 10/14 px gaps, 18 px side
padding). It is here so the layout can be reviewed — and re-rendered after a
change — without a phone in hand.

Dependencies::

    python3 -m pip install Pillow arabic-reshaper python-bidi

Usage::

    python3 scripts/render_home_preview.py            # writes docs/previews/home-1-8.png
"""
from __future__ import annotations


from pathlib import Path

import arabic_reshaper
from bidi.algorithm import get_display
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs" / "previews" / "home-1-8.png"

S = 2
W = 360 * S

URDU = str(ROOT / "app/assets/fonts/Amiri-Regular.ttf")  # the app's Arabic/Urdu heading face
# The app renders Latin labels with the platform sans; on this machine DejaVu
# is the closest stand-in. Any sans will do — only the preview changes.
LATIN = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
LATIN_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
ICON = Image.open(ROOT / "app/assets/images/shiaverse_icon.png").convert("RGB")

BG = (16, 23, 21)
CARD = (26, 36, 33)
BORDER = (48, 60, 56)
PRIMARY = (122, 196, 162)
ON_PRIMARY = (9, 32, 25)
TEXT = (232, 238, 232)
MUTED = (150, 164, 156)
FOREST = (20, 91, 69)
FOREST_DARK = (14, 59, 52)
GOLD_TEXT = (228, 215, 185)


def ufont(px):
    return ImageFont.truetype(URDU, px)


def lfont(px, bold=False):
    return ImageFont.truetype(LATIN_BOLD if bold else LATIN, px)


def shaped(value: str) -> str:
    return get_display(arabic_reshaper.reshape(value))


def rtl(d, x, y, value, f, color):
    d.text((x, y), shaped(value), font=f, fill=color, anchor="ra")


def rounded(d, box, radius, fill=None, outline=None, width=1):
    d.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def gradient(size, start, end):
    img = Image.new("RGB", size)
    dd = ImageDraw.Draw(img)
    for y in range(size[1]):
        t = y / max(1, size[1] - 1)
        dd.line([(0, y), (size[0], y)],
                fill=tuple(int(start[i] + (end[i] - start[i]) * t) for i in range(3)))
    return img


def paste_rounded(canvas, img, box, radius):
    mask = Image.new("L", (img.size[0] * 4, img.size[1] * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, img.size[0] * 4 - 1, img.size[1] * 4 - 1), radius=radius * 4, fill=255)
    canvas.paste(img, box, mask.resize(img.size, Image.LANCZOS))


def main() -> None:
    pad = 18 * S
    canvas = Image.new("RGB", (W, 1096), BG)
    d = ImageDraw.Draw(canvas)

    cc = "ShiaVerse"
    d.text((W - pad - d.textlength(cc, font=lfont(20, True)), 22), cc, font=lfont(20, True), fill=TEXT)
    rtl(d, pad + 48 * S, 24, "⤓", lfont(15), MUTED)

    top = 62 * S
    bh = 150 * S
    bw = W - 2 * pad
    paste_rounded(canvas, gradient((bw, bh), FOREST_DARK, FOREST), (pad, top), 26 * S)
    icon_box = 84 * S
    paste_rounded(canvas, ICON.resize((icon_box, icon_box), Image.LANCZOS),
                  (pad + 18 * S, top + (bh - icon_box) // 2), 20 * S)
    right = W - pad - 18 * S
    rtl(d, right, top + 12 * S, "ShiaVerse", lfont(20, True), (255, 255, 255))
    rtl(d, right, top + 46 * S, "قرآن، دعائیں، نہج البلاغہ اور چودہ کتبِ احادیث", ufont(15), GOLD_TEXT)
    btn_w, btn_h = 178 * S, 38 * S
    btn = (right - btn_w, top + bh - 18 * S - btn_h, right, top + bh - 18 * S)
    rounded(d, btn, 19 * S, outline=(150, 190, 175), width=2)
    rtl(d, right - 14 * S, btn[1] + 9 * S, "محفوظات اور نوٹس", ufont(15), (255, 255, 255))

    # ---- the slim last-seen strip (54 dp) -----------------------------------
    bar_top = top + bh + 12 * S
    bar_h = 54 * S
    rounded(d, (pad, bar_top, W - pad, bar_top + bar_h), 18 * S, fill=CARD, outline=BORDER, width=2)
    rtl(d, W - pad - 30 * S, bar_top + 10 * S, "آخری مطالعہ", ufont(15), PRIMARY)
    d.text((W - pad - 26 * S, bar_top + 14 * S), "⌄", font=lfont(16), fill=PRIMARY)
    d.text((W - pad - 18 * S, bar_top + 16 * S), "◷", font=lfont(11), fill=PRIMARY)
    label_w = int(d.textlength(shaped("آخری مطالعہ"), font=ufont(15))) + 44 * S
    divider = W - pad - label_w
    d.line([(divider, bar_top + 14 * S), (divider, bar_top + bar_h - 14 * S)], fill=BORDER, width=2)

    chips = [
        ("قرآنِ کریم · آج 16:53", "پارہ 29 • آیت 20", True),
        ("مفاتیح الجنان · آج 16:31", "دعائے کمیل، دعا نمبر 8", False),
        ("نہج البلاغہ · کل 21:04", "خطبہ 159", False),
    ]
    x = divider - 10 * S
    for title, detail, latest in chips:
        f, f2 = ufont(15), ufont(14)
        w = max(int(d.textlength(shaped(title), font=f)), int(d.textlength(shaped(detail), font=f2))) + 22 * S
        if x - w < pad + 4 * S:
            w = x - pad - 4 * S
            if w < 90 * S:
                break
        box = (x - w, bar_top + 7 * S, x, bar_top + bar_h - 7 * S)
        rounded(d, box, 14 * S, fill=PRIMARY if latest else (36, 47, 43),
                outline=PRIMARY if latest else BORDER, width=2)
        rtl(d, x - 11 * S, box[1] + 1 * S, title, f, ON_PRIMARY if latest else (214, 224, 218))
        rtl(d, x - 11 * S, box[1] + 22 * S, detail, f2,
            (9, 40, 32) if latest else MUTED)
        x = box[0] - 8 * S

    # ---- the prayer banner (112 dp, fixed height: this row never moves) -----
    banner_top = bar_top + bar_h + 14 * S
    banner_h = 112 * S
    rounded(d, (pad, banner_top, W - pad, banner_top + banner_h), 22 * S,
            fill=CARD, outline=BORDER, width=2)
    ring = 46 * S
    ring_left = W - pad - 14 * S - ring
    ring_top = banner_top + (banner_h - ring) // 2
    d.ellipse((ring_left, ring_top, ring_left + ring, ring_top + ring),
              outline=BORDER, width=4 * S)
    # three quarters of the way through the Asr window
    d.arc((ring_left, ring_top, ring_left + ring, ring_top + ring),
          start=-90, end=180, fill=PRIMARY, width=4 * S)
    d.text((ring_left + 16 * S, ring_top + 13 * S), "◷", font=lfont(15), fill=PRIMARY)

    bx = ring_left - 12 * S
    rtl(d, bx, banner_top + 10 * S, "عصر", ufont(19), PRIMARY)
    name_w = int(d.textlength(shaped("عصر"), font=ufont(19)))
    rtl(d, bx - name_w - 20 * S, banner_top + 10 * S, "۴:۰۲", ufont(17), TEXT)
    rtl(d, bx, banner_top + 40 * S, "باقی ۱ گھنٹے ۴۱ منٹ", ufont(15), GOLD_TEXT)
    rtl(d, bx, banner_top + 68 * S, "کراچی • ۳:۲۳ سے عصر کا وقت", ufont(13), MUTED)
    act = 36 * S
    act_box = (pad + 14 * S, banner_top + (banner_h - act) // 2)
    d.ellipse((act_box[0], act_box[1], act_box[0] + act, act_box[1] + act),
              fill=(38, 34, 22), outline=(120, 96, 40), width=2)
    d.text((act_box[0] + 10 * S, act_box[1] + 8 * S), "◎", font=lfont(16), fill=GOLD_TEXT)

    # ---- tasbeeh and Qibla cards (62 dp, same glass as the banner) ----------
    row_top = banner_top + banner_h + 10 * S
    row_h = 62 * S
    card_w = (W - 2 * pad - 10 * S) // 2

    # Tasbeeh (the first card in reading order, so it sits on the right).
    t_left = W - pad - card_w
    rounded(d, (t_left, row_top, W - pad, row_top + row_h), 20 * S,
            fill=CARD, outline=BORDER, width=2)
    tring = 38 * S
    tring_left = W - pad - 12 * S - tring
    tring_top = row_top + (row_h - tring) // 2
    d.ellipse((tring_left, tring_top, tring_left + tring, tring_top + tring),
              outline=BORDER, width=3 * S)
    d.arc((tring_left, tring_top, tring_left + tring, tring_top + tring),
          start=-90, end=-90 + 331, fill=PRIMARY, width=3 * S)
    rtl(d, tring_left + 19 * S, tring_top + 9 * S, "۳۴", ufont(14), PRIMARY)
    rtl(d, tring_left - 10 * S, row_top + 9 * S, "تسبیح", ufont(16), TEXT)
    rtl(d, tring_left - 10 * S, row_top + 34 * S, "آج: ۱۳۴ • ہدف ۳۳", ufont(13), MUTED)

    # Qibla.
    q_left = pad
    rounded(d, (q_left, row_top, q_left + card_w, row_top + row_h), 20 * S,
            fill=CARD, outline=BORDER, width=2)
    needle_left = q_left + card_w - 12 * S - tring
    d.text((needle_left + 10 * S, row_top + (row_h - 24 * S) // 2), "➤",
           font=lfont(18), fill=GOLD_TEXT)
    rtl(d, needle_left - 10 * S, row_top + 9 * S, "قبلہ نما", ufont(16), TEXT)
    rtl(d, needle_left - 10 * S, row_top + 34 * S, "۲۶۸° مغرب • ۲۸۰۰ کلومیٹر", ufont(13), MUTED)

    # ---- the library --------------------------------------------------------
    y = row_top + row_h + 22 * S
    rtl(d, W - pad, y, "قرآن، دعائیں، فتاویٰ اور نہج البلاغہ", ufont(21), TEXT)
    y += 40 * S
    x = W - pad
    for title, sub in (
        ("دینی مسائل (احکام و فتاویٰ)", "فتاویٰ، احکامِ شرعیہ اور سوال و جواب"),
        ("صحیفہ سجادیہ", "دعائیں، مناجات، ترجمہ اور حواشی"),
    ):
        cw, ch = 190 * S, 158 * S
        if x - cw < pad:
            break
        rounded(d, (x - cw, y, x, y + ch), 20 * S, fill=CARD)
        rtl(d, x - 14 * S, y + 10 * S, "◈", lfont(14), PRIMARY)
        rtl(d, x - 14 * S, y + 54 * S, title, ufont(18), TEXT)
        rtl(d, x - 14 * S, y + 96 * S, sub, ufont(14), MUTED)
        rtl(d, x - 14 * S, y + ch - 32 * S, "ابواب دیکھیں  ‹", ufont(14), PRIMARY)
        x -= cw + 12 * S

    y += 158 * S + 26 * S
    rtl(d, W - pad, y, "کتبِ احادیث", ufont(21), TEXT)
    y += 40 * S
    for i, (name, latin) in enumerate([("الکافی", "Al-Kafi"), ("غرر الحکم", "Ghurar al-Hikam")]):
        cw = (W - 2 * pad - 12 * S) // 2
        bx = W - pad - i * (cw + 12 * S)
        rounded(d, (bx - cw, y, bx, y + 126 * S), 20 * S, fill=CARD)
        rtl(d, bx - 14 * S, y + 12 * S, "▤", lfont(14), PRIMARY)
        rtl(d, bx - 14 * S, y + 46 * S, name, ufont(19), TEXT)
        d.text((bx - cw + 14 * S, y + 100 * S), latin, font=lfont(11), fill=MUTED)
        rounded(d, (bx - 34 * S, y + 92 * S, bx - 14 * S, y + 108 * S), 8 * S, fill=(36, 47, 43))

    d.text((pad, 1046), "design preview — ShiaVerse 1.8 home screen (dark theme)",
           font=lfont(12), fill=(105, 122, 112))
    out = OUTPUT
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out)
    print("wrote", out, canvas.size)


if __name__ == "__main__":
    main()
