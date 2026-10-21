# The launcher widget — a plate that fits the cell (1.24)

The home-screen widget is the app's smallest surface: one verse, its
reference, and a button that asks for the next one. It is drawn entirely in
Android drawables and filled by `MomentWidgetProvider`, so it works without
the app running and without a network.

## Two plates, one provider

The launcher tells a widget how much room it has
(`AppWidgetManager.getAppWidgetOptions`). The provider cuts the plate to fit:

| Cell | Layout | What it shows |
|------|--------|---------------|
| tall (≥ 110 dp) | `res/layout/moment_widget.xml` | the verse, the next prayer, the Hijri date, the reference |
| short (< 110 dp) | `res/layout/moment_widget_small.xml` | the verse and its reference |

Both layouts carry the same view ids (`moment_root`, `moment_text`,
`moment_reference`, `moment_refresh`, `moment_next_prayer`, `moment_hijri`), so
one update fills either of them and nothing else in the provider has to know
which plate it is painting. The widget may be resized down to a single row of
text (`minResizeWidth`/`minResizeHeight`); the size it gets when it is added
has not changed.

## The 3D plate

The widget is not a flat card any more. `moment_widget_background.xml` is a
layer-list that stacks five pieces of the same object:

1. the shadow the plate casts on the wallpaper,
2. the steel of the plate itself (a diagonal gradient),
3. the light falling along its top edge,
4. the shadow gathering under it,
5. the gold rim.

The amber **lens** badge (`moment_widget_lens.xml`) and the round **refresh
knob** (`moment_widget_button.xml`) are drawn the same way: a radial gradient
for the material, a lighter radial gradient for the light on it, and a rim.
The next prayer sits in a sunk chip (`moment_widget_chip.xml`).

## The next prayer

The app writes the next prayer and the Hijri date into its own preferences
(`widget_next_prayer`, `widget_hijri` in
`app/lib/services/prayer_controller.dart`), and the widget reads them from the
same file. The plate on the home screen therefore shows the time the card in
the app shows, and the two can never disagree. The controller writes them only
when the next prayer actually changes, not on every tick of the clock.
