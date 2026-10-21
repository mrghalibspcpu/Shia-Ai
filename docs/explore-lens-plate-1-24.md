# Xplore — the lens plate (1.24, revised)

The Xplore page is one full-screen portrait plate, taken from the reference
artwork: a brushed-metal body with amber camera lenses climbing it diagonally
and three red plates cut into the edges of that body — the brand wedge in the
top-right corner, the pointing wedge on the left edge, and the corner wedge in
the bottom-right that carries the radial-menu button. Hatched graticule wedges
sit in the metal between the lenses. It replaces the two-column grid that
shipped in 1.21–1.23.

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
| 6 | اثنا عشری انسائکلوپیڈیا | left edge, y 0.28 | 0.44 × 0.38 of the field | red wedge |
| 7 | Radial menu | bottom-right corner | 0.46 × 0.34 of the field | red corner wedge + round button |

`lens = min(width × 0.40, height × 0.20)`: about 156 px on a 390 × 844 phone,
which keeps the five lenses and both plates clear of each other while leaving
the metal visible between them, as in the artwork.

The lenses carry no number tags: the control number was an annotation of the
artwork, and a numbered ring on a phone reads as a dial the reader has to
count. The engraving says what the lens does, and nothing else.

## The three red plates

The plates are triangles, cut the way the artwork cuts them, and each one is
described by three corners in unit coordinates of its own box:

| Plate | Box | Corners | Right angle |
|-------|-----|---------|-------------|
| brand | top-right, 0.62 × 0.185 of the field | (0,0) (1,0) (1,1) | in the screen's corner |
| wedge | left edge, 0.44 × 0.38, top 0.28 | (0,0) (0,1) (1,0.5) | on the edge, pointing in |
| corner | bottom-right, 0.46 × 0.34 | (1,0) (1,1) (0,1) | in the screen's corner |

`_PlateGeometry` holds the box and the corners; `_TrianglePlate` paints the
plate (a bevelled edge, brushed steel, a shadow on the metal) and clips
whatever sits on it to the triangle, so no control can spill off the plate.

Two numbers come out of the geometry:

- the **incentre** — the centre of the triangle's inscribed circle — is where
  a round control sits: the radial button on the corner plate, the book's
  glyph on the wedge;
- the **hypotenuse angle** is the angle the brand wordmark is laid at, so
  «Xplore / by ShiaVerse» runs along the edge of the plate as in the artwork.

The radial menu fans out of the round button on the corner plate, so the menu
grows out of the button it belongs to.

## The radial menu

The round button is inside the corner plate. Tapping it (or its plate) fans
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

1. a knurled barrel (90 comb teeth and a highlight arc),
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
