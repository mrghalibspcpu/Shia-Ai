# Exact location, the home prayer card, and your own wirds (1.9)

What readers asked for after 1.8, and how each request was answered. Nothing
else changed: the library, the readers, search, saved items, downloads, the
theme and the stored data of 1.8 all carry over (the stored location, the
tasbeeh counts and the prayer settings load as they are).

## 1. The location is the exact place

1.8 printed «میرا موجودہ مقام» for every GPS fix, knew 70 cities, and never
looked again once a location was stored. 1.9:

* **Names every fix.** A fix is named at once from the bundled list
  (`app/assets/geo/cities.tsv.gz`, see below) — the town it belongs to, in Urdu
  when it is one of the curated cities, «… کے قریب» when the fix is outside it.
  When the phone is online the name is then upgraded to the exact place by
  OpenStreetMap's reverse geocoder (Nominatim, with BigDataCloud as the
  fallback), e.g. «G-11، اسلام آباد» with «اسلام آباد، پاکستان» under it. The
  upgrade is stored, so it happens once per fix.
* **Finds a better fix.** High accuracy (GPS) first, then the network position,
  then the last known position — instead of one medium-accuracy try.
* **Says why when it cannot.** Location switched off, permission refused,
  refused for ever, or no signal — each has its own message and the one button
  that fixes it (open the location switch, ask again, open the app settings,
  try again). Coming back from the settings retries by itself.
* **Re-detects quietly.** On launch, a stored IP or default location is
  replaced by a GPS fix when the permission is already there, and a GPS
  location older than three hours is re-checked (and only replaced when the
  reader has really moved, > 1 km). Never a prompt; a manually chosen city is
  never touched.
* **Finds every city.** The picker searches the curated list (now 181 cities
  with Urdu names, 96 of them in Pakistan), then **73,023 places** offline —
  every GeoNames place of ~500+ people in Pakistan, India, Afghanistan, Iran,
  Iraq, the Gulf, the Levant and Central Asia, and every town of ~5,000+
  elsewhere — and, for villages, online (Open-Meteo's GeoNames search while
  typing, OpenStreetMap on «انٹرنیٹ پر تلاش»). Typed coordinates are named from
  the offline list.

`app/lib/services/city_index.dart` keeps the 73,000 names in one string (and a
lower-case twin with identical offsets) and the coordinates in typed lists: a
search is a few native `indexOf` calls, the nearest-town scan never allocates,
and the whole index is ~3 MB in memory, parsed off the UI thread.

The nearest town is scored by distance minus a bonus for the log of its
population, so a fix in Islamabad's G-11 is «اسلام آباد» (not the closer small
neighbourhood centre, and not Rawalpindi), while a fix in a separate town keeps
that town's name.

`scripts/build_city_index.py` rebuilds the list from two PyPI packages
(`geonamescache` and `reverse_geocoder`, GeoNames data, CC BY 4.0); the output
is deterministic.

## 2. Larger text, English digits

* Every text in the prayer section is larger (labels 13–15, times 17–19, the
  next prayer 23), and numbers use the system sans face with tabular figures,
  so the clock does not jitter.
* Prayer times, Qibla and tasbeeh print **English digits** (5:04, 256°, 3,528
  کلومیٹر, 33 / 100). The helpers in `app/lib/astro/prayer_format.dart` keep
  their names; `displayDigits()` also converts any Urdu/Arabic-Indic digit
  that arrives from elsewhere. The rest of the app (Quran ayah numbers, hadith
  numbers) keeps its Urdu digits.

## 3. The home prayer card

The home screen now opens with a mini prayer section: the place (tap to change
it), the weekday and date, the **Hijri date**, a live clock with seconds, the
running prayer («ابھی: ظہر کا وقت»), the next prayer with a stopwatch countdown,
and the five times — over a **living sky** that follows the day's own prayer
times:

| Sky | From | Until | Animation |
| --- | --- | --- | --- |
| سحر (dawn) | Fajr | sunrise + 40 min | breathing horizon glow, fading stars, drifting mist, birds |
| دوپہر (day) | sunrise + 40 min | Asr | sun glow and slow rays, drifting clouds, birds |
| شام (evening) | Asr | Maghrib + 25 min | warm sun glow, tinted clouds, first stars, a flock |
| رات (night) | Maghrib + 25 min | Fajr | twinkling stars, two shooting stars per loop |

The four paintings are `app/assets/images/sky_*.jpg` (~370 kB together); the
animation is one `CustomPainter` behind a `RepaintBoundary`, so the text never
repaints with it. It stops when another tab or screen is in front (muted
ticker) and when the phone asks for reduced motion. The full prayer screen's
header uses the same sky.

**Hijri date** — `app/lib/astro/hijri_calendar.dart`: the Umm al-Qura month
starts for 1430–1480 AH (checked day by day against `hijri-converter`), the
arithmetical calendar outside that range. After Maghrib the card shows the next
date as its eve («شبِ …»). South Asia usually sights the moon a day after
Makkah, so Pakistan/India start one day behind by default; the prayer screen
has «ہجری تاریخ کی درستگی» (automatic, −2…+2 days).

## 4. Your own count and your own wird

* **Any one-step zikr takes any count**: quick choices 33, 72, 100, 110, 313,
  1000 and unlimited, or a typed number up to 1,000,000. Salawat, istighfar and
  tawheed remember their own count; Tasbeeh-e-Zahra stays 34/33/33.
* **Write your own wird**: «نیا ورد» saves the words, an optional meaning or
  intention, and the count; saved wirds appear as chips (long-press to edit or
  delete) and in the switch sheet. «اپنا ذکر» itself can be rewritten too.
* **«ایک واپس (−1)»** takes back a bead counted by mistake.
* Everything is stored in the same `tasbeeh_v2` blob with new optional keys
  (`custom_text`, `custom_note`, `wirds`, `targets`); a 1.8 blob loads as is.

## 5. The circular mini tasbeeh

Next to a small Qibla dial on the home screen: the count inside a progress ring
with a travelling bead (tap the ring or **+** to count), the running wird under
it, reset (tap to confirm, long-press for instant), today's total, a switch to
any zikr or saved wird, and a button to the full counter. Both cards have a
fixed height, so the home list never jumps while counting.

## 6. One tile for مفاتیح الجنان و صحیفہ سجادیہ

Like «دینی مسائل», the two prayer books are now one card on the home row.
`DuaCollectionScreen` offers both, each with its own count, download button and
«جاری رکھیں» row. The books themselves, their search, their last-read
positions and their deep links are unchanged.

## Delivery

The version is **1.9.0 (11)**, signed with the same CI key, so it installs over
1.8 and keeps the downloaded books. The workflow publishes
`ShiaVerse-1.9.0.apk` and, new, `ShiaVerse-1.9.0.zip` on the `app-v1.9.0`
pre-release.

## Tests

New suites: `hijri_calendar_test.dart` (dates, shifts, every day of the table,
sky phases), `city_index_test.dart` (parsing, ranking, nearest town, Urdu
labels, the bundled asset itself), `place_names_test.dart` (the four online
payloads). Extended: the controller (exact-name upgrade, no overwrite of a
chosen city, quiet re-detection, Hijri at Maghrib and its stored shift), the
tasbeeh (wirds, targets, undo, persistence, corrupt storage), the location
store (new fields, 1.8 compatibility, IP names in Urdu), and the formatting
helpers (no Urdu digit left in the prayer section).
