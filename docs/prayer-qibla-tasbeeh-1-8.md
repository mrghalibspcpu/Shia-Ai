# Prayer timings, Qibla compass, and the digital tasbeeh (1.8)

Three daily utilities now live inside ShiaVerse, sharing one set of
coordinates and one visual language: the Shia (Jafari) prayer times with a
live countdown, a magnetometer Qibla compass, and a digital tasbeeh with the
Tasbeeh-e-Zahra (s.a.) workflow. They open from the home screen — a glass
banner for the next prayer, and a row with the counter and the compass — and
each has its own full screen. Nothing else about the app changed: the library,
the readers, the search, the saved items and the theme are untouched.

## One location, asked for once

`PrayerController` (created once in `main.dart`) owns the coordinates:

1. **Device fix** — `geolocator`, medium accuracy, 12 s time limit.
2. **IP lookup** — `ipapi.co`, then `ipwho.is` if the first fails.
3. **Manual city** — a searchable offline list of 70 cities (Karachi to
   Dearborn, Mahshad to Sydney), or a typed coordinate pair.
4. **Islamabad** — the last resort, so the card is never empty.

Whatever is resolved is stored in `SharedPreferences`
(`prayer_location_v1`), so the *next* launch opens offline and instantly with
the reader's own city and never touches the GPS or the network again.

The coordinates are the single input to all three features: the timing engine,
the Qibla bearing, and the "distance to the Kaaba" on the compass card all read
the same `PrayerLocation`. The compass screen explicitly does not ask for a
second fix.

## The timing engine

`app/lib/astro/prayer_calculator.dart` is pure Dart — no Flutter, no platform
channels — so all of it is covered by `flutter test`.

* **Method** — `adhan_dart` (the Dart port of the Adhan library), preset
  `jafari()`: **Fajr 16°, Isha 14°, Maghrib at 4°** (Sunni Asr, as Shia
  fiqh takes the earlier shadow). The second preset is the Leva/Tehran
  reading of the specification — **Fajr 17.7°, Isha 14°, Maghrib at 4.5°** —
  and both are switchable on the timings screen.
* **Nisf al-Layl** — the midpoint between **Maghrib and the next Fajr** (the
  Shia night begins at Maghrib). The strict solar midpoint (sunset → sunrise)
  is published alongside it in `midnightCandidates()` for cross-checking; over
  most of the year they differ by minutes.
* **Sunrise and sunset** — the astronomical markers the specification asks for,
  shown as chips under the five prayers.
* **Zones** — every time on the card is the wall clock of *the location*, not
  of the phone. `solarZoneOffset()` keeps the device's own offset when it is
  plausible for those coordinates — so Indian +5:30, Gulf zones and DST all
  keep working — and falls back to the longitude when the phone is plainly set
  to the wrong zone (a phone stuck on UTC would otherwise show Islamabad's Fajr
  at 11:30 at night). The published clock (`PrayerController.now`) is that same
  wall clock, which is why the countdown, the "current window" highlight and
  the alert watcher can never disagree.

### What the screen shows

* **Hero header** — a soft light Islamic wallpaper (mosque dome and minarets
  under a dawn sky, `app/assets/images/prayer_hero.jpg`, 30 kB) with a cream
  veil that keeps the text readable; the place, its coordinates and the date
  sit on top.
* **Next prayer** — name, live countdown, and how far the *running window* has
  progressed (Fajr closes at sunrise, Isha at Nisf al-Layl, and after midnight
  the night's Isha window runs to Fajr).
* **Glass timing row** — the five prayers with the active one filled and the
  next one outlined in gold, plus chips for sunrise/sunset/Nisf al-Layl. Each
  cell scales its own digits (`FittedBox`), so no width, font or translation can
  make the row clip.
* **Detail tiles** — Nisf al-Layl, the last third of the night, the calculation
  method with its angle, the Qibla bearing, the distance, and where the
  coordinates came from (`جی پی ایس / انٹرنیٹ (IP) / منتخب کردہ شہر / ڈیفالٹ`).
* **Alerts** — notification, chime and vibration switches. A prayer's arrival
  plays `chime_prayer.wav`, buzzes three times, and raises the post-prayer
  prompt (below).
* **Urdu numbers** — clock times, countdowns, dates and coordinates all use
  Arabic-Indic digits via `astro/prayer_format.dart`, reusing the app's existing
  `arabicNumerals()`.

## The Qibla compass

* **Bearing** — the formula in the specification, implemented directly in
  `PrayerCalculator.qiblaBearing()`: `atan2(sin Δλ · cos φ₂, cos φ₁ · sin φ₂ −
  sin φ₁ · cos φ₂ · cos Δλ)`, normalised to 0–360°. `qiblaBearing(33.6844,
  73.0479) = 255.9123°` (Islamabad), matching the reference implementation to
  four decimals across the six cities the tests pin.
* **Heading** — `flutter_compass`, which reads Android's rotation vector (or,
  on devices without one, the accelerometer and magnetometer pair) and
  `CLLocationManager`'s heading on iOS, where the platform has already applied
  the magnetic declination, so the needle points at *true* north on both.
* **Smoothing** — `HeadingFilter` keeps an unwrapped angle and moves it by the
  short way round towards each reading. A naive average across the 359°→0° seam
  flips the needle through half a turn; this one does not, and
  `AnimatedRotation` gets the unwrapped value so the rose turns smoothly. Tests
  walk the filter across the seam.
* **Calibration and edge cases** — a "compass enable" banner while the sensor is
  silent (or refused), a calibration card graded from the platform's accuracy
  report, the figure-8 hint, a "lay the phone flat" reminder, and a green
  **الائن / کیلیبریٹڈ** state with a short haptic pulse when the heading comes
  within 5° of the Qibla (18° reads as "close"). When no sensor is available the
  card still gives the bearing, the compass point and the distance — the answer
  without the needle.

## The digital tasbeeh

* **Zikr modes** — Tasbeeh-e-Zahra (s.a.) with **automatic advance**: 34× Allahu
  Akbar → 33× Alhamdulillah → 33× Subhanallah → a new round. Plus salawat,
  istighfar, tawheed, and a custom counter.
* **Targets** — 33, 100, 1000, or unlimited, with a progress ring (plus tick
  marks for the small targets), a fill bar, and the remaining count.
* **Feel** — a ripple at the tap point, a selection haptic, a quiet click
  (`tap_click.wav`, SoundPool low-latency on Android), and on completion a
  double medium haptic with an ascending three-note chime
  (`chime_complete.wav`).
* **Persistence** — one JSON blob (`tasbeeh_v2`): preset, step, count, rounds,
  the custom target, settings, today's total, the lifetime total, and the
  day stamp. The daily counter rolls over by itself at midnight; the lifetime
  total never does. A kill, a restart or a device reboot never loses a count.
* **Reset** — a confirm dialog, and a long-press for a one-touch clear. Neither
  touches today's or the lifetime totals.

## The crossing points

* **Shared coordinates** — the compass, the timings and the home banner read one
  `PrayerController`; the compass screen never asks for a location again.
* **Post-prayer shortcut** — `PrayerSchedule.justPrayed()` reports the prayer
  whose time arrived in the last half hour (and Fajr's window closing at
  sunrise, for a reader who prayed late). The dashboard then offers
  **تسبیحِ زہرا (س) شروع کریں** in a sheet; accepting arms the sequence and
  opens the counter. After 30 minutes the offer expires quietly, so reopening
  the app does not nag.
* **Same glass** — all three widgets are painted from `GlassPalette` /
  `GlassPanel` (cream glass, emerald, gold, `#f4f6f8` page in light mode;
  smoked glass in dark mode) with the same radii, borders and elevation as the
  rest of the dashboard. The home banner has a fixed height, so the countdown
  and the location resolving cannot shift the list under the reader's thumb.

## Sounds

`scripts/make_alert_sounds.py` synthesises the three WAVs that ship in
`app/assets/audio/` (~190 kB total): a two-strike prayer chime, a three-note
completion chime, and a very quiet tap click. No third-party audio, no
downloads, and the script is deterministic — rerunning it after an edit is the
only way to change them.

## Verification

* `flutter test` — four new suites (42 Dart files in total are guarded):
  * `prayer_engine_test.dart` — the presets' angles, the day's times for
    Islamabad/Karachi/London checked against the reference implementation the
    Dart port is based on, method-independent markers, Nisf al-Layl, the Qibla
    formula for six cities, the zone rule, and the window/countdown/post-prayer
    logic on a hand-built day.
  * `compass_math_test.dart` — the filter's smoothing and its behaviour across
    north, the unwrapped angle for the rotation tween, the alignment thresholds
    and the direction of the turn hint.
  * `tasbeeh_controller_test.dart` — the full Zahra sequence advancing by
    itself, target changes, unlimited mode, reset, the daily rollover, and the
    stored state surviving a restart.
  * `prayer_location_test.dart` + `prayer_controller_test.dart` — both IP
    payload shapes, typed coordinates, the city search, the storage round trip,
    the alert firing exactly once, and the manual/stored/fallback location
    paths (with the GPS and the network stubbed out).
* `python3 scripts/check_dart.py` — the offline syntax/import/symbol guard, now
  also recognising typed top-level constants (`const Color kGold = …`), which is
  what kept it from flagging files that only use a colour or font constant.
* `docs/previews/home-1-8.png` — the home screen re-rendered with the banner and
  the utility row in place (`scripts/render_home_preview.py`), so the layout can
  be reviewed without a phone.
