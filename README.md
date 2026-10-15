# ShiaVerse

An offline Shia study library for Android: the Quran with Urdu translation and
tafseer notes, Mafatih al-Jinan, Nahj al-Balagha, and the 14-book Urdu/Arabic
hadith corpus — with full-text search, bookmarks, notes, and reader themes that
all run on the device.

> The AI chat/Gemini integration was removed from this project. Everything here
> is local: no API keys, no backend service, no network calls except the optional
> corpus download described below.

## What is in this repository

- `app/` — Flutter client: library home, Quran (surah/juz/page), Mafatih
  al-Jinan, Nahj al-Balagha, hadith reader, unified search, bookmarks/notes,
  data download manager, and settings.
- `assets/shia-databases.zip` — the 14 original hadith databases (~222 MiB
  expanded, 43 MiB compressed).
- `assets/quran.db`, `assets/mafatihdb-v4.db`, `assets/nahjul_balagha.db` — the
  three standalone collections, normalised to the same SQLite settings as the
  other books.
- `assets/database-manifest.json` — sizes, SHA-256 digests, row counts, titles,
  and download locations for all 20 databases. `app/assets/database-manifest.json`
  is the identical copy bundled into the APK.
- `scripts/` — normalisation, packaging, publishing, and verification tools.
- `docs/apk-analysis.md` — findings and signing/licensing limits of the supplied
  compiled APK.

## Reader/search update (1.4)

Sahifa Sajjadiyya and the uploaded Khamenei/Sistani Urdu fatawa are now part of
both the library and unified search. Quran scrolling is lazy, with surah/ayah
jump controls. Search shows total matches and additional pages, and opens the
matching text with normalized highlighting. See
[`docs/reader-search-update.md`](docs/reader-search-update.md) for preservation,
coverage, migration and verification details.

## Fatawa, last-seen, and instant start (1.5)

- Every fatawa answer ends with the official page it was taken from and an
  **اصل ماخذ پر جائیں** button, so a ruling can be verified at the source.
- The two Urdu fatawa books are one library entry, **دینی مسائل (احکام و فتاویٰ)**;
  tapping it opens a marja picker with both authorities.
- Sahifa Sajjadiyya shows the book's 83 supplications and nothing else — the
  site's biography, lecture and quiz pages are no longer listed as duas.
- Two kinds of last-seen: the global **آخری مطالعہ** (book, reference, time) and
  one saved position per book, shown on the home screen and inside each book.
- The home screen opens immediately, with or without downloaded data, and a
  download prompt at the top; the search index builds in the background.

See [`docs/library-1-5-update.md`](docs/library-1-5-update.md).

## One slim last-seen strip, real book names, and the ShiaVerse icon (1.7)

- The home screen used to list every saved position as its own full-width card
  under **ہر کتاب کا آخری مقام**, which buried the library. All of it now fits
  in a single 54 dp strip: a fixed **آخری مطالعہ** label, the books scrolling
  through it sideways (newest first, the most recent one filled), and a button
  that opens the complete list with every reference. See
  [`docs/library-1-7-update.md`](docs/library-1-7-update.md).
- Five books now carry their real titles: **غرر الحکم** (`hakam.db`),
  **ہدایۃ العلم** (`hidaya.db`), **حکمت نامۂ رسول اکرم(ص)**
  (`hikmatprophet.db`), **حکمت نامہ امام حسین(ع)** (`imam.db`) and
  **کتاب التوحید** (`towheed.db`). Only labels changed — no file name, key,
  digest or row count moved, so installed data is untouched.
- The launcher icon and the in-app logo are the uploaded **ShiaVerse** plate.
  `scripts/make_app_icons.py` renders it into the adaptive icon (Android 8+),
  the round icon (API 25) and every legacy density, so no launcher mask can
  clip the wordmark.

## Prayer timings, Qibla compass, and the digital tasbeeh (1.8)

Three daily utilities, sharing one set of coordinates and one design language.
They open from the home screen — a glass banner with the next prayer and its
live countdown, and a row with the counter and the compass — and each has its
own screen.

- **Shia (Jafari) prayer timings.** `adhan_dart` with the Jafari/Leva-Qum preset
  (Fajr 16°, Isha 14°, Maghrib at 4° — the disappearance of the eastern red
  twilight), or the Tehran reading (Fajr 17.7°, Maghrib 4.5°). Nisf al-Layl is
  the midpoint of sunset to the next Fajr, with the precautionary
  maghrib-based reading printed beside it. Every time on the card is the wall
  clock of *the place*, not of the phone, so a phone set to the wrong timezone
  cannot print Isha in the afternoon. A hero header paints the mosque wallpaper
  with the place, the date and the day's times on glass over it.
- **Location, asked for once.** GPS → IP lookup → manual city (70 cities, offline
  list) → Islamabad. Whatever wins is stored, so later launches open instantly,
  offline, and the compass never asks for a second fix.
- **Qibla compass.** The specification's bearing formula from those same
  coordinates, and the phone's own magnetometer for the heading, smoothed by a
  filter that cannot snap through the north seam. A green
  **الائن / کیلیبریٹڈ** state (with a short haptic) when the phone is within 5°
  of the Qibla; the bearing, the compass point and the distance to the Kaaba are
  shown even on a phone with no sensor at all.
- **Digital tasbeeh.** Tasbeeh-e-Zahra (s.a.) advances by itself
  (34× Allahu Akbar → 33× Alhamdulillah → 33× Subhanallah), plus salawat,
  istighfar, tawheed and a custom counter with 33/100/1000/unlimited targets. A
  ripple, a selection haptic and a quiet click on every tap; a double haptic and
  a three-note chime when a step completes. Counts, today's total and the
  lifetime total survive a kill, and the daily counter rolls over by itself.
- **Post-prayer shortcut.** Within half an hour of a prayer's time (and of Fajr's
  window closing at sunrise) the dashboard offers **تسبیحِ زہرا (س) شروع کریں**,
  which arms the sequence and opens the counter.

See [`docs/prayer-qibla-tasbeeh-1-8.md`](docs/prayer-qibla-tasbeeh-1-8.md), and
`docs/previews/home-1-8.png` for the home layout re-rendered with the new
widgets.

## App name and icon

The launcher label and the in-app title are **ShiaVerse**. The icon artwork is
`app/ShiaVerseIcon.png`; `python3 scripts/make_app_icons.py` derives
`app/assets/images/shiaverse_icon.png` (the logo the UI paints) and every
Android density, round and adaptive icon from it — rerun it after replacing the
artwork. The Android package id stays
`com.shiaai.app` on purpose: changing it would make the phone treat the build
as a different app, so an update could not install over the old one and every
downloaded database would be lost.

## Speed

The 1.5 work (background search index, cached bookmarks, lazy readers) also
applies here, and the last-seen strip keeps it that way: the whole home screen
still reads `SharedPreferences` once for the strip instead of once per card, the
chips are built lazily as they scroll in, and only the two images the UI
actually paints are bundled — `logo.png` and `tasneemlogo.png` left the bundle
when the ShiaVerse plate replaced them, which is dead weight off the APK and off
first-launch unpack.

## Smooth scrolling

- The search index yields to the UI between batches, so the ~96k-row walk no
  longer starves the frame while a reader is scrolling.
- Bookmarks and notes are cached in memory; every card used to make two
  `SharedPreferences` round trips (and rebuild twice) as it scrolled in.
- Reader lists drop automatic keep-alives and each card sits behind a
  `RepaintBoundary`, which keeps long chapters from accumulating elements.
- Images decode at their display size instead of at full resolution.


## The corpus

| Collection | File | Contents |
|---|---|---|
| Quran | `quran.db` | 6,236 verses, 114 surahs, Urdu translation (`tr`), tafseer notes (`talighe`), juz/page locators |
| Mafatih al-Jinan | `mafatihdb-v4.db` | 677 catalogue entries and 5,378 text lines across 6 chapters |
| Nahj al-Balagha | `nahjul_balagha.db` | 3,742 paragraphs, 810 entries, 2,352 footnotes, 504 introduction paragraphs |
| Sahifa Sajjadiyya | `Sahifa_Sajjadiyya_full_runtime.sqlite3` | The book's 83 supplications (4,318 of the 4,993 supplied rows; the rest is site furniture) |
| Khamenei Urdu fatawa | `khamenei_urdu_fatawa.sqlite` | All 428 supplied question/answer records with source references |
| Sistani Urdu fatawa | `sistani_urdu_fatawa.sqlite` | All 1,619 supplied question/answer records with source references |
| 14 hadith books | `shia-databases.zip` | 96,513 records, 17,855 sections, 845 chapters |

`python3 scripts/normalize_databases.py` rewrites the three standalone files so
every database shares one configuration: SQLite `page_size` 1024 (the setting the
original 14 books use), UTF-8, the `shia_*` reader indexes, fresh statistics, and
no free pages. Row data is never modified — the script re-checks row counts and a
content fingerprint before it replaces a file.

```sh
python3 scripts/normalize_databases.py --dry-run   # report only
python3 scripts/normalize_databases.py             # rebuild in place
python3 scripts/prepare_databases.py --write-manifest
```

## Data delivery: small APK, fast first launch

The APK does **not** have to carry the corpus. `app/lib/data_installer.dart`
downloads each database on demand:

1. The bundled manifest (`app/assets/database-manifest.json`) lists every file,
   its size, and its SHA-256.
2. The app fetches `<name>.db.gz` from GitHub — a build-pinned mirror first
   (`--dart-define=SHIA_DATA_BASE_URL`), then the latest release, then the
   repository itself.
3. Interrupted downloads resume with HTTP `Range` requests.
4. The stream is gunzipped straight to disk while it is hashed; a file whose
   digest does not match the manifest is deleted, never opened.
5. `LibraryRepository.refreshAfterInstall()` picks the new book up and appends it
   to the search index without rebuilding what is already there.

Books can also be bundled at build time (see below); when a file is already in
app storage the download is skipped, and when it is missing the library shows it
as "not installed" with a download button instead of failing.

Publish the corpus once per change:

```sh
python3 scripts/prepare_databases.py --write-manifest
python3 scripts/publish_databases.py          # writes dist/*.db.gz (222 MiB -> ~53 MiB)
gh release create databases-v1 dist/*.gz dist/database-manifest.json \
    --title "Corpus v1" --notes "SQLite collections for the Shia library app"
```

## Build and run the app

Requirements: Flutter stable, Android SDK, Java 17, and a device or emulator.

```sh
cd app
flutter pub get
flutter run
```

That builds a small APK that downloads its data on first launch. To ship an
offline APK with everything inside (~230 MiB of assets), unpack the databases
first:

```sh
python3 scripts/prepare_databases.py --output app/assets/databases
cd app && flutter build apk --release
```

## Checks

```sh
python3 -m unittest discover -v          # packaging/manifest unit tests
python3 scripts/verify_corpus.py         # every database opens; sample lookups work
python3 scripts/verify_client_sql.py     # the Dart queries replayed against real data
python3 scripts/check_dart.py            # syntax/imports/removed symbols without a Dart SDK
cd app && flutter analyze && flutter test
```

`verify_client_sql.py` extracts each statement from
`app/lib/library_repository.dart` and executes it, so the Dart and the schema
cannot drift apart unnoticed. `check_dart.py` needs
`pip install tree-sitter tree-sitter-dart` and is a guard for environments
without Flutter; `flutter analyze` remains the real type check.

## Build a signed APK in GitHub Actions

`.github/workflows/android-apk.yml` validates the corpus, replays the client
SQL, runs the Python and Flutter checks, then builds a release APK and uploads a
30-day artifact. The workflow has a `bundle_databases` switch
(`workflow_dispatch`) for offline APKs; by default the APK ships without data.
Without owner signing secrets it uses the Android debug key and labels the result
**preview/debug-signed** — for testing only.

For an owner-signed release, add these repository Actions secrets:

- `ANDROID_KEYSTORE_BASE64` — base64-encoded owner keystore
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

Optionally set the non-secret repository Actions variable `SHIA_DATA_BASE_URL` to
a mirror that serves the corpus files. Never commit a keystore or a credential.

### Downloading the APK on a phone

Every build on a pushed branch publishes a pre-release named
`app-v<version>` whose asset is `ShiaVerse-<version>.apk` — the file name
carries the version on purpose, so a phone never reuses a half-downloaded copy
of an older build. Two things happen after the upload:

1. the release notes are written with the file's exact size and SHA-256, so a
   download can be checked instead of guessed at;
2. a **Verify the hosted APK is the APK we built** step downloads the published
   asset again and fails the run if its digest differs from the APK the run
   produced — a truncated or stale asset stops the build, not the reader.

`cd app && flutter build apk --release` still works locally; that is the same
APK, just without the CI signature (see
[`app/android/ci-signing/README.md`](app/android/ci-signing/README.md)).

A newly generated APK is not automatically a Google Play update. Updating the
Play-installed app requires the original package identity, signing key, and any
required Play licensing/configuration; this project does not bypass those checks.
See [`docs/apk-analysis.md`](docs/apk-analysis.md).
