# Shia AI

A bilingual Shia hadith library and citation-grounded assistant, rebuilt as a native Flutter/Android client over the supplied Urdu/Arabic corpus.

## What is in this repository

- `app/` — Flutter client, Android project, Nastaleeq and Amiri fonts, library/reader/search/bookmark screens, and the Shia AI chat UI.
- `assets/shia-databases.zip` — the 14 original SQLite databases (about 42 MiB compressed; about 190 MiB expanded). `assets/database-manifest.json` records their verified hashes and row counts.
- `shia_ai/` — local FTS5 search and the optional Gemini-backed, source-citing HTTP service. Gemini credentials stay on the backend.
- `scripts/` — safe database extraction and corpus validation.
- `docs/apk-analysis.md` — findings and signing/licensing limitations of the supplied compiled APK.

The corpus has 96,513 paragraph records, 17,855 sections, and 845 chapters. The original databases remain unchanged. The mobile client builds a persistent on-device full-text index on first launch; it prefers SQLite FTS5, uses FTS4 where FTS5 is unavailable, and retains a basic SQL fallback.

## Prepare and run the Flutter app

Requirements: Flutter stable, Android SDK, Java 17, and an Android device/emulator.

```sh
python3 scripts/prepare_databases.py --output app/assets/databases
cd app
flutter pub get
flutter run
```

The database bundle is checked in compressed form. Extraction produces ignored `app/assets/databases/*.db` files so Flutter can bundle the original records without committing a second expanded copy. First launch copies the books into app-private storage and creates the local search index; allow some time and storage for this initial setup.

The app provides the book → chapter → section → reader hierarchy, bookmarks and per-record notes, paper/sepia/night reader themes, bilingual justified search, and a retained AI conversation. A citation's **Check** control opens the exact book/record; its reader action returns to the same chat. From a normal reader, the floating AI action switches to that chat with the current record as context.

## Run the AI backend

The reader and local search work without Gemini. For citation-grounded chat on the phone, open **ترتیبات** and paste a Google AI Studio API key (`AIza…`). The key stays in Android secure storage and is never compiled into the APK. Search still runs against the on-device books; Gemini only drafts the answer from those hits.

To serve the same chat from a hosted backend instead, configure the server (never the APK) with `GEMINI_API_KEY` and `SHIA_API_TOKEN`, then run:

```sh
python3 scripts/prepare_databases.py
python3 -m shia_ai.api
```

If a Google AI Studio key is pasted into the old URL/token fields, the app treats it as a Gemini key. Optional backend URL/token fields remain under advanced settings. A shared token in a public client is not strong user authentication; use a properly protected/rate-limited backend for a public deployment. See [`.env.example`](.env.example) and [`docs/api.md`](docs/api.md). No live Gemini credentials are present and a real Gemini request has not been tested in this workspace.

Run backend tests with:

```sh
python3 -m unittest discover -v
```

## Build a signed APK in GitHub Actions

`.github/workflows/android-apk.yml` validates the corpus, runs Python and Flutter tests/analyzers, then builds a release APK. It uploads a 30-day artifact. Without owner signing secrets, it uses the Android debug key and labels the result **preview/debug-signed**; that is for testing only.

For an owner-signed release, add these repository Actions secrets:

- `ANDROID_KEYSTORE_BASE64` — base64-encoded owner keystore
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

Optionally set the non-secret repository Actions variable `SHIA_AI_API_BASE_URL` to the service URL. Never commit a keystore, Gemini key, or backend credential. The workflow removes its temporary keystore after building.

A newly generated APK is not automatically a Google Play update. Updating the Play-installed app requires the original package identity, signing key, and any required Play licensing/configuration; this project does not bypass those checks. See [`docs/apk-analysis.md`](docs/apk-analysis.md).
