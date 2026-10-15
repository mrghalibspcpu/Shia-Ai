# Library 1.7 — ایک پتلی آخری مطالعہ پٹی، اصل نام، اور نیا آئیکن

Three requests from the reader, all of them in the client: the home screen is
usable again, the books carry their real titles, and the app wears the uploaded
ShiaVerse plate.

## 1. The last-seen bar replaces the stack of cards

Before, the home screen showed the global **آخری مطالعہ جاری رکھیں** card and
then one full-width card per book under **ہر کتاب کا آخری مقام**. With a dozen
books open, that list *was* the home screen — the collections row and the hadith
grid had been pushed off the bottom of the phone.

Now one 54 dp strip carries all of it:

| Piece | What it does |
|---|---|
| **آخری مطالعہ** label | Fixed on the leading edge, so the reader always knows what the strip is |
| Scrolling chips | One per book, newest first. Each chip is `book · reference · time`; the newest is filled with the primary colour |
| ⤢ button | Opens every entry as a full card (`LastReadTile`) in a bottom sheet, with the complete reference |

- `app/lib/widgets/last_seen_bar.dart` is the whole widget; the home screen only
  supplies a list.
- The list comes from one `getLastReads()` pass, filtered to books that are
  installed. The global `last_read_v2` entry is folded in **only when that book
  has no per-book entry** (a pre-1.5 install), so the newest position is never
  printed twice.
- Chips are `ListView.builder` items: a reader with 20 saved positions pays for
  the five on screen, not twenty.
- Tapping a chip opens the reader at that exact record — the same
  `openLastRead()` path as before, so position saving is unchanged.
- Nothing was removed from storage: both `last_read_v2` and
  `last_read_book_<key>` are still written by `saveLastRead()`, and the
  in-book **جاری رکھیں** rows inside each reader are untouched.
- The strip renders nothing at all when there is no history, so a fresh install
  shows the same home screen it did before.

## 2. Real book names

Five labels were wrong; the reader sees the real titles now:

| Key (unchanged) | File (unchanged) | Was | Now |
|---|---|---|---|
| `hakam` | `hakam.db` | حِکَم | **غرر الحکم** |
| `hidaya` | `hidaya.db` | الہدایہ | **ہدایۃ العلم** |
| `hikmatprophet` | `hikmatprophet.db` | حکمتِ پیغمبر | **حکمت نامۂ رسول اکرم(ص)** |
| `imam` | `imam.db` | حکمتِ ائمہ | **حکمت نامہ امام حسین(ع)** |
| `towheed` | `towheed.db` | التوحید | **کتاب التوحید** |

The same five titles are updated in `assets/database-manifest.json`,
`app/assets/database-manifest.json` (the copy bundled in the APK) and
`scripts/database_specs.py`, which is what regenerates them — the two manifests
stay byte-identical.

**No database is affected.** File names, keys, SHA-256 digests, sizes and row
counts are untouched, so `scripts/prepare_databases.py` still validates against
the manifest and an installed app keeps every downloaded book. The titles are
labels the client reads, never data it queries.

## 3. The ShiaVerse icon everywhere

`app/ShiaVerseIcon.png` (the uploaded plate) is the single source of truth.
`scripts/make_app_icons.py` renders it — deterministically — into:

- `app/assets/images/shiaverse_icon.png` — the logo the home banner and the
  start-up screen paint (512 px, drawn at 80–116 dp).
- `mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png` — the legacy launcher icon
  (API 24–25 read this bitmap).
- `mipmap-*/ic_launcher_round.png` — the same icon clipped to a circle for
  launchers that request a round one.
- `mipmap-*/ic_launcher_foreground.png` + `mipmap-anydpi-v26/ic_launcher.xml`
  — the adaptive icon Android 8+ uses. The artwork sits inside the 72 dp safe
  zone of the 108 dp canvas and fades into a blurred, darkened copy of itself,
  so a circular or squircle mask cannot clip the wordmark or leave a seam.
- `mipmap-*/ic_launcher_splash.png` (112 dp) — the bitmap the launch screen
  centres. It is a plain raster, never the adaptive-icon XML: `<bitmap>` cannot
  draw an `<adaptive-icon>`.

The manifest now points at `@mipmap/ic_launcher` (+ `@mipmap/ic_launcher_round`),
which is what makes Android pick the adaptive icon on 8+ and the density bitmap
on 7.x; `values-v31/styles.xml` names the Android 12+ splash background and
icon, and `launch_background.xml` paints the icon's own navy (`#05061A`) instead
of white, so the tap-to-first-frame flash is gone.

`app/pubspec.yaml` bundles only what the UI paints: `shiaverse_icon.png` plus
the two marja portraits. `logo.png` and `tasneemlogo.png` are no longer
referenced by any screen, so they left the bundle — a few hundred kilobytes less
APK and less to unpack on first launch. The files stay in the repository.

## Checks

- `python3 scripts/check_dart.py` — 24 Dart files, no problems.
- `python3 -m unittest discover` — corpus, tooling and client-model tests pass.
- `python3 scripts/prepare_databases.py` — the corpus still matches the
  manifest, label change and all.
- `flutter analyze` / `flutter test` / `flutter build apk` — CI, as usual.
