# White home and coordinated readers (1.12)

## Home and dock

- The five dock destinations are **Home, Settings, Bookmarks, Last seen, More**.
  Quran, hadith and duas remain on their existing side cards; no collection or
  entry point was removed. Search stays in its working home search bar and in
  the reading hub. The More sheet keeps all of its previous utilities.
- Dock icons fill 76 dp-tall containers on a 360 dp phone, with 4 dp between
  neighbours. English labels sit below the containers, not inside them. The
  tray is white and its outer edges use the same width cap and inset as home.
- Home scales by width but takes the **available height** instead of centring
  a fixed 610 dp drawing. The side cards share that height equally. Search and
  the last (دینی مسائل) card therefore have exactly the same bottom baseline,
  just above the dock. No artificial blank band precedes the dashboard.
- Side headings are now 17.5 design units (previously 12.5), with 12-unit
  slogans, centred alignment and room for three title lines. Short cards scale
  their whole content down only when necessary, rather than dropping words.
- The spine turns the other way (`quarterTurns: 3`) and uses 24-unit branding
  instead of 14.
- Prayer content has a distinct location row, a centred clock and Hijri date,
  then a two-row **3 + 2** prayer grid. The active prayer, Now tag, next-prayer
  countdown, animated sky and location-refresh action are retained.
- The tasbeeh uses 99% of the available diameter (previously 90%), a larger
  centre lens, a directional metal face, machined bevel, engraved ticks and a
  cast shadow. Count, progress, wird picker, expand, reset confirmation and the
  persisted long-press reset lock have not changed.

## White by default, system bars included

The home backdrop, dock, utility pages and default reader paper are white.
Previously selected dark/sepia themes are still respected; their preference
keys have not changed. Edge-to-edge mode and transparent system bars let the
white page reach the top of the display, while SafeArea still protects content
from the status icons and camera cut-out. Android's initial status bar is also
white with dark icons, avoiding the old navy strip on launch.

## Readers

`widgets/reader_chrome.dart` supplies a shared `ReaderScaffold` to Quran,
hadith, Mafatih, Sahifa, Nahj al-Balagha and fatawa readers. Each keeps its own
loader, search target and lazy list. The header follows the home collection's
emerald/teal/blue/plum gradient, rounded shape and gold hairline. A compact
appearance button opens the font controls and all three existing palettes in
one sheet, making room for a useful title and the Quran jump action.

Passage cards have gold hairlines, a quiet reference/action strip, larger Arabic
text and more breathing space. Notes, bookmarks, copying, folded commentary,
source verification and word-level search highlighting are retained. Mafatih
stays a continuous supplication with one bookmark for the entire dua, **not** a
new bookmark for each line. Extra bottom padding keeps the last passage clear
of the floating reading hub. The hub retains all five previous actions, now
with English labels matching the dock.

## Preservation and checks

- Android package id, CI signing key, corpus files, manifest digests, database
  queries, preference keys and reading-record ids are unchanged.
- Version is **1.12.0+15** so the APK can update an existing compatible install.
- Existing Python corpus and Dart guard tests remain in place.
- `ui_layout_test.dart` retains the original time-of-day, short-phone, custom
  wird and reset-lock checks and adds baseline/status-inset assertions, dock
  labels outside their boxes, actual HomeShell actions, 320/412/800 dp widths,
  all reader types, white/night/large-font readers, and bookmark/note/appearance
  persistence checks. CI exports its rendered phone screens as previews.
- The existing Android workflow analyzes and tests Flutter before building and
  signing the APK, then publishes both the APK and a ZIP and verifies the
  hosted APK against the bytes built by that run.
