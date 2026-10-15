# Shia Library

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

A newly generated APK is not automatically a Google Play update. Updating the
Play-installed app requires the original package identity, signing key, and any
required Play licensing/configuration; this project does not bypass those checks.
See [`docs/apk-analysis.md`](docs/apk-analysis.md).
