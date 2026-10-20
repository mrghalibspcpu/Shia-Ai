# Bottom panel, reading hub, and the light home (1.10)

## What changed on the home screen

- The top app bar (download and bookmarks icons) was removed. Download is in the
  bottom panel; bookmarks and settings are two buttons below the tasbeeh.
- The Qibla dial was removed from the home screen. It is a bottom-panel action.
- The prayer card lost the Gregorian date, the Qibla icon in its header, the
  "next prayer" block and the "now" line. It keeps the Hijri date and the clock.
- In the five-prayer strip, the running prayer is tagged **Now**. The next
  prayer is outlined in gold and shows the time left inside its box.
- The last-seen strip moved out of the home screen. The bottom panel's
  **آخری مطالعہ** button opens the same complete list in a sheet
  (`showLastSeenSheet`).
- The green ShiaVerse card and its icon were removed from the home screen.

## The bottom panel

Five buttons, in this order (right to left):

| Button | Action |
|---|---|
| کتب | Home tab (books); pops back to the home screen |
| تلاش | Search tab on the home screen; on top of a page, opens search above it |
| آخری مطالعہ | Opens the last-seen list in a sheet |
| قبلہ نما | Opens the Qibla compass above the current page |
| ڈاؤن لوڈ | Opens the data and download screen above the current page |

The panel is `HomeDock` in `app/lib/widgets/reading_hub.dart`. It is the
bottom bar of the home shell, so it is hidden whenever a page covers the home
screen.

## The reading hub

`ReadingDepthObserver` (a `NavigatorObserver`) counts the page routes pushed on
top of the home screen. `PageRoute` only: dialogs and bottom sheets do not
count. Each time the count changes, a post-frame callback updates a
`ValueNotifier<int>`.

`ReadingHub` wraps the whole navigator in `MaterialApp.builder`. While the count
is above zero it shows a round button at the bottom centre (the ShiaVerse logo,
turning into a close mark while open). Tapping it fans the five destinations out
on an arc above the button. Every destination opens on top of the current page,
so the page underneath is never moved or rebuilt. Closing the menu, tapping the
dimmed background, or tapping the centre button again returns to the page as it
was.

The routing for each destination is `_runHubAction` in `app/lib/main.dart`.

## Theme and colours

- Light is the default theme with a white page. A phone that has never saved a
  theme choice, or that still holds the old "system" choice, is moved to light
  once (`light_default_applied`). A light or dark choice made in settings is kept.
- Every book's icon has its own colour: `bookAccent(book)` picks from
  `kBookPalette` by the book's position in `BookDefinition.all`.

## Checks

The change was made without a Flutter SDK in the sandbox, so the proof is the
CI run: `flutter analyze`, `flutter test` (the layout test renders the home card
at four times of day and with a large font), and the release APK build. The
Dart parser check (`python3 scripts/check_dart.py`) passes.
