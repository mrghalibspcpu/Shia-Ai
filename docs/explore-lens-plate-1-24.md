# Xplore — the lens plate (1.24)

The Xplore page is one full-screen portrait plate, taken from the reference
artwork: a brushed-metal body with amber camera lenses climbing it diagonally,
two red bevel plates at the edges, and hatched graticule wedges in the metal
between them. It replaces the two-column grid that shipped in 1.21–1.23.

## Where each container sits

`app/lib/screens/explore_screen.dart` positions the six destinations by
fractions of the safe area, so the rhythm survives every phone:

| # | Destination | Anchor (x, y of the field) | Size | Material |
|---|-------------|---------------------------|------|----------|
| 1 | تسبیح و ذکر | 0.20, 0.155 | 1.00 × lens | amber lens |
| 2 | نماز کے اوقات | 0.505, 0.335 | 1.08 × lens | amber lens |
| 3 | چاند کی رویت | 0.795, 0.505 | 0.94 × lens | amber lens |
| 4 | اسلامی تقویم | 0.515, 0.675 | 1.00 × lens | amber lens |
| 5 | Xplore Xtra | 0.215, 0.838 | 0.88 × lens | amber lens |
| 6 | اثنا عشری انسائکلوپیڈیا | left edge, y 0.435 | 0.92 × lens | red bevel plate |
| 7 | Radial menu | bottom-right corner | 1.02 × 0.78 lens | red plate + round button |

`lens = min(width × 0.40, height × 0.20)`: about 156 px on a 390 × 844 phone,
which keeps the five lenses and both plates clear of each other while leaving
the metal visible between them, as in the artwork.

## The radial menu

The round button is inside container 7. Tapping it (or its plate) fans
`HubDestination.values` — Home, Search, Bookmarks, Xplore, Settings — along a
quarter-arc left of and above the plate, and a scrim closes the menu again. The
page underneath never moves; the same five destinations are reached exactly as
from the app-wide hub.

Geometry, learned from the rendered test: the five dials sit on a 90° arc, so
neighbours are `radius × π/8` apart while each dial carries a caption beneath
it. `radius = min(width, height) × 0.535` and a ~58 dp dial leave a 75 dp step
on a 360 dp phone — enough for the caption to sit on open plate instead of
under the next circle. Both numbers are smaller/larger respectively than the
first attempt (0.40 radius, 74 dp dial), which drew overlapping rings and
captions on top of the neighbouring dial.

## Previews

`docs/previews/xplore-1-24/` holds the phone-sized renderings the CI layout
test produces (`app/test/ui_layout_test.dart`, `SHIAVERSE_PREVIEW_DIR`):
`plate-800dp.png`, `plate-640dp.png` and `radial-menu.png`. They come from the
real widget tree, so they show what Flutter actually painted — including the
one-pixel overflow stripe that the radial menu carried until 1.24.

## The engraving

Each lens paints four layers in code, no bitmaps:

1. a knurled barrel (120 comb teeth, a highlight arc, the control number),
2. a radial glass gradient with five coating rings and a crescent of light,
3. a dark centre disc with the destination's title (and its subtitle when the
   title fits on one line — measured with a `TextPainter`, so a two-line title
   never collides with it),
4. a drop shadow that lifts the lens off the metal.

## Preview

```sh
python3 -m pip install --break-system-packages Pillow arabic-reshaper python-bidi
python3 scripts/render_explore_preview.py    # docs/previews/explore.png
```

The renderer mirrors the same fractions and the same layer order, so a layout
change can be reviewed without a phone. It uses the app's Amiri face because
Pillow can only rasterise Jameel Noori Nastaleeq where libraqm is installed.
