# The home dashboard (1.11)

This note replaces the home layout of `docs/home-1-10-1.md` (the prayer banner,
the 290 px tasbeeh circle and the five full-width section cards). The bottom
panel's five buttons keep their slots but carry different features, and the
search moved from the panel to the dashboard.

The screen is the fifteen containers of the approved design, in the design's
shapes, sizes and positions.

## One canvas, scaled as a piece

`HomeDashboard` (`app/lib/widgets/home_dashboard.dart`) draws everything on a
fixed **352 × 610** design canvas and scales that canvas to whatever the phone
offers: `scale = min(width / 352, height / 610)`, never above `1.45` so a tablet
shows the same dashboard centred instead of stretching it. A 360 dp phone gets
scale ≈ 1 (the design's own measurements); a 640 dp-tall phone gets ≈ 0.94 and
still shows the whole dashboard, because the whole screen shrinks together
instead of re-flowing. Text scaling inside the canvas is clamped to 1.0 —
the design is a drawing, and the canvas itself already scales.

The design units are the constants at the top of that file:

| Piece | Size |
|---|---|
| Canvas (with its 6 px padding) | 352 × 610 |
| Right column (containers 3–7) | 90 wide, 110 tall each, 8 between |
| Left column | 242 wide |
| Rail (1) | 42 × 190 |
| Prayer card (2) | 192 × 190 |
| Moment card (8) | 242 × 80 |
| Dial (9) | `min(width, height) × 0.9` of whatever is left, ≈ 212 |
| Search bar (10) | 242 × 46 |

The two columns are laid out as the design draws them for an Urdu reader: the
**ShiaVerse rail down the right edge** (the near side) with the wide column —
prayer card, moment card, dial, search bar — to its left, and the five collection
cards down the left edge.

`scripts/render_home_preview.py` draws the same dashboard with the app's fonts
and the same measurements; `docs/previews/home-1-11.png` is its output.

## The containers

| # | Widget | What it does |
|---|---|---|
| 1 | `_TitleRail` | The ShiaVerse mark and the name down the spine (`RotatedBox`, quarter turn 1). |
| 2 | `_MiniPrayerCard` | `SkyBackdrop` (animated: dawn, day, evening, night), the place, the live clock, the Hijri date, and the five prayers in one strip — the running one lit and tagged **Now**, the next one outlined in gold with its countdown. Tapping opens the timings screen; the button at the end of the place row re-detects the location. |
| 3–7 | `_SectionCard` | One `HomeSection` each: قرآنِ کریم, احادیث, مفاتیح الجنان و صحیفہ سجادیہ, نہج البلاغہ, دینی مسائل. Title, one small slogan, and the collection's mark. Not installed → the download mark and the data screen. |
| 8 | `_MomentCard` | آیت / حدیثِ وقت, see below. The `آیت` / `حدیث` tag is a pill on the card's edge, with its word rotated a quarter turn; the row it sits in lays its members out top-to-bottom, because a turned box reads its constraints bottom-up. |
| 9 | `_TasbeehDial` | See below. |
| 10 | `_SearchPill` | Opens `SearchScreen(autofocus: true)` — the search itself is unchanged. |
| 11–15 | `HomeDockBar` | گھر, قرآن, احادیث, دعائیں, مزید. |

## آیت / حدیثِ وقت

`LibraryRepository.momentPassages()` returns six short lines: three Quran ayahs
whose Urdu translation is 40–130 characters (`ORDER BY RANDOM()`) and three
narrations from Mizan al-Hikmah (`Parags.mean` 30–130 characters), shuffled
together. The card keeps the list in a `static` field, so it is rolled **once
per app start** — a new line every time the app opens — and the button at its end
walks the list without touching the database again. Tapping the card opens the
passage in its own reader (`pushReaderFor`), which is what the record id on every
line is for.

Before anything is downloaded the card shows `kFallbackMoments` (three verses and
one narration, in `app/lib/models.dart`), so the container is never empty and the
tap simply moves to the next line.

## The tasbeeh dial

The wird (`step.arabic`) is printed in the Arabic face along the top and is
tappable, which opens the wird picker. The count glows inside the plum bead and
the bead itself counts on tap; the ring around it shows the progress towards the
target. **+** is filled emerald; the reset button is cream metal.

Long press on the reset button locks it and the button becomes the lock
(`Icons.lock`) — tapping a locked reset only says so, it never clears the count —
and a long press unlocks it again. The state is kept in `SharedPreferences`
(`tasbeeh_reset_locked`), because a lock that forgets is no lock. The expand
button at the top of the dial opens `TasbeehScreen`.

The face is painted by `_DialPainter`: a radial metal gradient, a swept-gold rim,
the turning marks of a real bead frame, and the progress arc.

## The bottom panel and **مزید**

`HomeDockItem` defines the five buttons; the three collections on it reuse
`HomeSection`, so a button and a card open the same screen the same way
(`openHomeSection`). **گھر** refreshes the dashboard, **مزید** opens the sheet.

`_moreFeatures` in `app/lib/main.dart` is that sheet's list: نہج البلاغہ,
دینی مسائل, نماز کے اوقات, تسبیح و ذکر, قبلہ نما, محفوظات, آخری مطالعہ,
ڈیٹا ڈاؤن لوڈ and ترتیبات. `showMoreFeaturesSheet` now scrolls, because nine
items do not fit a short phone.

The radial hub over a page keeps its five destinations (Home, تلاش, محفوظات,
مزید خصوصیات, ترتیبات); its search action opens the search screen as a page,
since there is no search tab any more.

## What was removed

`app/lib/widgets/home_utilities.dart` (the 1.10 prayer banner, the utility row
and the 290 px tasbeeh card) is gone: the dashboard owns the home screen now.
`HomeDock`, `_DockButton` and `kDockIconSize` left `reading_hub.dart` for
`HomeDockBar`; `HomeShell` no longer keeps an `IndexedStack` of two tabs.

`HomePrayerBanner` used to offer **تسبیحِ زہرا (س) شروع کریں** right after a
prayer's time; the timings screen still carries that prompt, and the dial is one
tap away on the dashboard.

## Checks

The change was made without a Flutter SDK in the sandbox, so the proof is the CI
run: `flutter analyze`, `flutter test` and the release APK build.
`app/test/ui_layout_test.dart` renders the dashboard at four times of day, with a
large system font, on a 640 dp-tall phone, taps the four action buttons of the
panel and locks/unlocks the reset button; the two new SQL statements were run
against the shipped `quran.db` and `mezan.db` before they were written.
`python3 scripts/check_dart.py` parses every file (`tree-sitter-dart`) and finds
no unused import, unresolved import or forbidden symbol.
