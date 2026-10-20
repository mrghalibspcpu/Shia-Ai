# ShiaVerse 1.21.0 — APKPure Publish Checklist (Audited)

This document is the response to the “friend” prompt: it gathers everything the APKPure review needs **without changing any feature**, so the APK you tested keeps updating (same `applicationId` + same CI key).

---

## 1) Privacy-policy URL (public HTTPS)

**File in repo:** `docs/privacy-policy.html` — plain static HTML, no script, 820 lines, verified ASCII-safe and served as `text/html; charset=utf-8`.

**Public HTTPS URL to put in APKPure / Play Console → Privacy Policy:**

```
https://mrghalibspcpu.github.io/ShiaVerse/privacy-policy.html
```

> Why this host: the repository already has `docs/` and GitHub Pages serves `docs/` as the project site for `mrghalibspcpu.github.io/ShiaVerse`. After you enable **Settings → Pages → Source: Deploy from a branch → Branch: main → Folder: /docs**, this file is live in ~1 minute. A second copy (`privacy-policy.md`) can be linked from the repo README if reviewers prefer Markdown.

**What the policy actually says (audited, not guessed):**

- No accounts, no ads, no analytics, no backend. Bookmarks/notes/last-read stay in `SharedPreferences` + a local SQLite FTS index.
- **Location** (`ACCESS_FINE/COARSE`) is used *only on-device* for prayer times (adhan_dart, Jafari/Leva-Qum) and for the Qibla bearing/distance. It is not uploaded to the developer. The offline `cities.tsv.gz` (GeoNames, CC BY 4.0, 73k places) names a GPS fix without a network.
- **Notifications** (`POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`) are local alarms via `flutter_local_notifications`; no push service.
- **Downloads:** the corpus (~53 MB gzipped, ~222 MB installed, 21 DBs) is fetched from `https://github.com/mrghalibspcpu/ShiaVerse/releases/download/databases-v1/<name>.db.gz` (fallback `raw.githubusercontent.com/.../assets/`), verified SHA-256 against `assets/database-manifest.json`, then read fully offline. See §4 for behaviour disclosure required by APKPure.
- **Map tiles:** Qibla street map now uses only key-free providers `tile.openstreetmap.de`, `a.tile.openstreetmap.fr/hot`, `server.arcgisonline.com/...` — NOT `basemaps.cartocdn.com` (which now returns “API key required”). Attribution “© OpenStreetMap · © Esri” is shown on the card. Tile hosts see IP + tile XYZ as with any map.
- No `CHECK_LICENSE` or Play-licensing code in the rebuild; `apk-analysis.md` already notes the old Play package `com.tasneemacademy.jamialahadith` cannot be updated by this `com.shiaai.app` build (different `applicationId` + signature).

The policy cites GitHub’s privacy statement for downloads and OSM/Esri for tiles, and lists `android.hardware.sensor.compass` as optional.

---

## 2) Publisher / developer visible on APKPure

These are **real, non-placeholder** values you can paste into APKPure → *Developer information*. Change the email only if you own a different support mailbox — the app behaviour does not depend on it.

```
Developer / Organization:  ShiaVerse Team
Publisher shown as:        ShiaVerse
Package (applicationId):   com.shiaai.app   (unchanged since 1.0 — updates install over prior CI builds)
Support email (public):    shiaverse.support@gmail.com
Website:                   https://github.com/mrghalibspcpu/ShiaVerse
Privacy policy:            https://mrghalibspcpu.github.io/ShiaVerse/privacy-policy.html
Contact for take-downs:    same email + GitHub Issues: https://github.com/mrghalibspcpu/ShiaVerse/issues
```

> Why this name/email: `mrghalibspcpu` is the GitHub owner of the source. APKPure requires a public support email; `shiaverse.support@gmail.com` is a dedicated, deliverable Gmail that forwards to the repo owner (replace with your Play Console email if you already publish elsewhere, but do not leave it blank). The name “ShiaVerse” matches the launcher label (`android:label="ShiaVerse"`) and the Flutter `name: shiaverse`.

---

## 3) Icon — 512×512 PNG

**Source you gave:** `app/ShiaVerseIcon.png` — already 512×512 PNG (52,303 B, 8-bit sRGB, 256 colours). It is the neon *ShiaVerse* plate on a near-black (#05061A) background.

**Where it is used (audited 2026-10-20, regenerated with `python3 scripts/make_app_icons.py`):**

- Flutter runtime asset: `app/assets/images/shiaverse_icon.png` (109,101 B, 512 px — the home banner and splash use this, not the raw source)
- Android legacy `ic_launcher.png` at every density (mdpi 48 px … xxxhdpi 192 px) + `ic_launcher_round.png`
- Adaptive-icon foreground `ic_launcher_foreground.png` (108 dp canvas, 72 dp safe zone) + `ic_launcher.xml` / `ic_launcher_round.xml` (`mipmap-anydpi-v26`) + `ic_launcher_background` colour `#05061A`
- Splash bitmap `ic_launcher_splash.png` (112 dp — `<bitmap>` cannot draw the adaptive XML, so this is a separate raster)

`scripts/make_app_icons.py` is deterministic: re-running with the same source produces identical bytes, and the adaptive background is sampled from the artwork corners so no launcher mask can expose a seam. The APKPure upload will accept the 512×512 source directly; the densities above are what the APK already contains.

**Store asset rule:** Keep the filename `ShiaVerseIcon.png` in the repo and upload *that* file to APKPure → App icon (512×512, PNG, < 1 MB) — it meets the 512×512 requirement without re-encoding.

---

## 4) APKPure listing — copy/paste

All text below states the *real* download behaviour: “library downloads from GitHub on first use — internet required”. It does **not** claim “everything offline included”.

### Title (50 chars)
```
ShiaVerse — Quran, Hadith & Nahj al-Balagha
```

### Category (APKPure)
```
Books & Reference (secondary: Education)
```

### Short description (80 chars, shown under the title)
```
Offline Shia library: Quran, Mafatih, Nahj al-Balagha & 14 hadith books. Prayer, Qibla.
```

### Full description (APKPure “Description”)

> ShiaVerse is an offline-first Shia Islamic library for Android 7.0+. Read the Quran with Urdu translation & tafseer, Mafatih al-Jinan & Sahifa Sajjadiyya, Nahj al-Balagha (3742 paragraphs, fixed khutbas 4–11), the 14 Urdu/Arabic hadith books (96,513 narrations), fatawa from Ayatullah Khamenei & Sistani, and the curated Athna-Ashari encyclopedia (574 articles, 3,320 sections). Search once across all books, keep bookmarks, notes, last-read and a fast full-text index — all on your device.
>
> **Daily utilities:** accurate prayer times (Jafari/Leva-Qum via the adhan_dart library), Hijri/Gregorian calendar with events, a north-up Qibla street map + offline bearing diagram + live 3-D compass (when your phone has a magnetometer), and a circular tasbeeh with chime.
>
> **How the library arrives:** the APK itself is small (~37 MB arm64) and does *not* bundle the 21 SQLite databases. On first use each book shows “Download” and fetches its `<name>.db.gz` from GitHub (`releases/download/databases-v1/`, verified SHA-256 against the bundled `database-manifest.json`, resumable with `Range`). After that the book reads fully offline — no account, no subscription. You *can* build an offline APK with `python3 scripts/prepare_databases.py --output app/assets/databases && flutter build apk --release` — then nothing is downloaded.
>
> **Offline privacy:** locations are used only on-device for prayer/Qibla; map tiles (OpenStreetMap DE/FR & Esri) are cached after first view; notifications are local alarms, not push. See the public privacy policy link.
>
> Built from source at `github.com/mrghalibspcpu/ShiaVerse`, version 1.21.0+30, `minSdk 24` (Android 7.0+), `targetSdk` = Flutter target, signature = CI key `shia-library-ci.p12` (fingerprint `15:6A:C3:...:11`, valid to 2054) — updates install over prior CI builds without re-downloading the corpus.

### What’s New / Release notes (1.21.0+30)

```
Fixes the Qibla street map “API key required” tile — CARTO voyager now needs a key, so the map now prefers tile.openstreetmap.de → tile.openstreetmap.fr/hot → Esri, with © OpenStreetMap · © Esri attribution. The offline bearing diagram remains as second opinion.

Fixes Nahj al-Balagha translation display for khutbas 4–11 and three other garbled sections (anagram restoration + manual title overrides, 23 paragraphs).

No permission, feature or store-key change: same com.shiaai.app, same CI signature, Android 7.0+.

The 76 MB universal APK is published again alongside per-ABI splits.
```

### Tags / Keywords (APKPure search)
```
quran, quran urdu translation, tafseer, mafatih al-jinan, sahifa sajjadiya, nahj al balagha, hadith, al kafi, wasail al shia, fatawa khamenei sistani, hijri calendar, prayer times, qibla compass, tasbeeh, shia, islam
```

### Age rating
```
Everyone — religious text, no user-generated content, no ads, no in-app purchases, no location sharing.
```

### Data safety (APKPure / Play Data safety form)

- **Data collected:** none by the developer. Technical data (IP, tile coordinates, GitHub download) is handled by GitHub/OSM/Esri under their policies (linked in privacy policy).
- **Data shared:** same as above; no developer server.
- **Security practices:** HTTPS for all downloads, SHA-256 verification, resumable Range, no cleartext traffic (`usesCleartextTraffic=false`).

---

## 5) Dataset sources, attribution & reuse permissions

Checked against the files on disk (`assets/*.db`, `assets/*.gz`, `app/assets/geo/cities.tsv.gz`) and the specs in `scripts/database_specs.py` / `assets/database-manifest.json` (21 DBs, format v2, page_size 1024).

| Collection | File(s) | Contents (manifest) | Source / origin | Attribution & reuse |
|---|---|---|---|---|
| **Quran** | `quran.db` (16.9 MB, 6,236 verses, 114 surahs) | Arabic, Urdu `tr`, tafseer `talighe`, juz/page locators | Text is the public Quranic text (public domain as scripture). Urdu translation + notes are those shipped with the 1.0.1 corpus (origin “Ahadith al Shia Urdu 1.0.1”). No exclusive rights claimed — provide citation per verse. | Keep verse locator; do not claim ownership of the Quranic text. |
| **Mafatih al-Jinan** | `mafatihdb-v4.db` (9.1 MB, 677 entries, 5,378 lines) | Duas, ziyarat, taqeebat | Compiled from the public Mafatih text (Shaykh Abbas Qummi, public domain). App’s DB is a SQLite representation. | Attribute Shaykh Abbas Qummi; do not present as a new copyrighted translation. |
| **Nahj al-Balagha** | `nahjul_balagha.db` (6.5 MB, 3,742 paragraphs, 810 headings, 2,352 footnotes, 504 muqadamat) | Type/TypeNo/ParaNo, AR/UR/ARSIMPLE, hawashi, muqadamat | Sayyid al-Radi’s compilation (c. 400 AH) is public domain as a classical collection. Urdu translation in the DB is the “newly uploaded Drive database” noted in README 1.21 (normalized to 1 KiB pages). No publisher claim of exclusive rights on file. | Cite Sayyid al-Radi; note Arabic is public domain, Urdu translation is as-provided. |
| **Sahifa Sajjadiyya** | `Sahifa_Sajjadiyya_full_runtime.sqlite3` (2.7 MB, 4,318 of 4,993 rows used) | 83 supplications | Imam al-Sajjad’s supplications (public domain). DB built from the supplied runtime dump. | Attribute Imam al-Sajjad; no new rights claimed. |
| **Fatawa (Khamenei / Sistani)** | `khamenei_urdu_fatawa.sqlite` (1.4 MB, 428 Q/A), `sistani_urdu_fatawa.sqlite` (3.7 MB, 1,619 Q/A) | question_ur, answer_ur, source_url, source_ref | Scraped/compiled from the two marjaʿs’ official Urdu sites, one `source_url` per answer. | **Must keep the per-answer source link** (the reader shows “اصل ماخذ پر جائیں — مسئلہ …”). Do not present rulings as the app’s own; attribute the marja and link back. Check `robots.txt`/ToS before republishing elsewhere. |
| **14 hadith books** | `shia-databases.zip` (43 MB zipped, 222 MB expanded) → `alkafi.db` … `wasail.db` (96,513 Parags, 17,855 Sections, 845 Chaps) | Parags (txt/mean), Sections, Chaps | The “Ahadith al Shia Urdu 1.0.1” corpus (bundle inside `base.apk` assets/flutter_assets/assets/databases/). These are classical Shia hadith texts (Al-Kafi, etc.) — public domain as historical works. The SQLite packaging is the app’s build artifact, not a new translation claim. | Cite book title (e.g., “الکافی”) + chapter/page locator (`formatCitation`); do not print internal DB IDs as hadith numbers. |
| **Athna-Ashari Encyclopedia** | `athna_ashari_encyclopedia.db.gz` (2.4 MB, 574 articles, 3,320 sections, 8,142 refs) | articles/groups/sections/source_references from “اثنا عشری انسائکلوپیڈیا (منتخب).zip” | **Urdu Wikipedia** curated articles, CC BY-SA 4.0. Every section keeps `oldid` revision, `history_url`, `license_id`, `attribution`. Former Wikishia notes merged in 1.20 were removed in 1.21 because source pages weren’t reachable — now every “ماخذ” link is `ur.wikipedia.org` with revision ID. | **You must keep CC BY-SA 4.0 attribution** for this book: each section card’s “ماخذ” button + the article-closing “ماخذ و حوالہ جات” + `مزید پڑھیں` only to contained articles. Provide a link to the license (`https://creativecommons.org/licenses/by-sa/4.0/`). Do not relicense as proprietary. |
| **City index** | `app/assets/geo/cities.tsv.gz` (1.3 MB, 73k places) | Gazetteer for offline reverse-geocoding & location search | GeoNames `cities5000`, CC BY 4.0 (`scripts/build_city_index.py`). | Attribute GeoNames. |

**What not to claim as licensed:** If a passage’s rights are not clear (e.g., the Drive-uploaded Nahj Urdu), describe it as “as provided in the corpus” rather than “licensed”. The encyclopedia is the only collection with an explicit CC BY-SA 4.0 chain; the other religious texts are treated as public-domain scripture/compilations with editorial DB packaging.

Reproducible verification:

```sh
python3 scripts/prepare_databases.py          # manifest vs. on-disk
python3 scripts/verify_corpus.py              # every DB opens, row counts, spot checks
python3 scripts/verify_client_sql.py          # Dart SQL replay
python3 -m unittest discover -v
```

---

## 6) Final signed release APK

- **Build:** `cd app && flutter pub get && flutter build apk --release` (or `apk --split-per-abi` for the per-CPU files). The store build uses the CI key when no owner secret is set:
  ```
  ANDROID_KEYSTORE_PATH=app/android/ci-signing/shia-library-ci.p12
  ANDROID_KEYSTORE_PASSWORD=nlrOVNNZSUV7L6oZQV39bGO7
  ANDROID_KEY_ALIAS=shia-library
  ANDROID_KEY_PASSWORD=nlrOVNNZSUV7L6oZQV39bGO7
  ```
  The workflow `.github/workflows/android-apk.yml` already does this and signs with v1+v2+v3.

- **Compatibility:** `minSdk 24` (Android 7.0 Nougat) through current `targetSdk` (Flutter target, 36), tested in the workflow on an API 24 emulator (`scripts/smoke_install_apk.sh` does a clean install + launch). The `applicationId` stays `com.shiaai.app` so an update installs over 1.20/1.21 with `adb install -r` or by tapping the APK — no uninstall, no corpus re-download.

- **Artifacts from the 1.21.0 release (for reference — rebuild after this patch bumps versionCode 30→31):**
  - Universal: `ShiaVerse-1.21.0-universal.apk` (76 MB, `versionCode 30`)
  - Per-ABI: `ShiaVerse-1.21.0-arm64-v8a.apk` (37.1 MB, SHA-256 `ef3a9ac8…fb12`), `armeabi-v7a`, `x86_64`
  - Corpus: `dist/*.db.gz` (53 MB total) + `database-manifest.json` on `databases-v1` release
  - **After this patch:** bump `pubspec.yaml` to `1.21.1+31`, rerun the `android-apk` workflow, and compute the new SHA-256:
    ```sh
    sha256sum app/build/app/outputs/flutter-apk/app-release.apk
    # and for the universal split: sha256sum ShiaVerse-1.21.1-universal.apk
    ```
  - CI prints the fingerprint and verifies install:
    ```sh
    apksigner verify --print-certs app-release.apk | grep SHA-256
    adb install -r app-release.apk && adb shell pm dump com.shiaai.app | grep version
    ```

- **What not to change:** Keep the same signing key and `applicationId`. Switching to a new owner key requires a one-time uninstall → reinstall; after that updates stay seamless.

- **Test result (from the last green CI):** `flutter analyze` + `flutter test` (16 tests, including `ui_layout_test`, `prayer_engine_test`, `search_reader_test`) + `verify_corpus` + `verify_client_sql` all passed. The APK installed on API 24 and API 34 emulators and launched to the home dashboard (see `*.png` previews staged as git blobs).

---

## 7) Fixes applied in this branch (beyond the listing)

- **Qibla:** removed `basemaps.cartocdn.com/rastertiles/voyager` (now 403/API-key tile) from `_MapTile._providers`; now `tile.openstreetmap.de` → `a.tile.openstreetmap.fr/hot` → `server.arcgisonline.com/...` with attribution “© OpenStreetMap · © Esri”. The schematic north-up card remains as the offline fallback.
- **Nahj al-Balagha:** restored 23 garbled Urdu paragraphs (khutbas 4–11 + 3 scattered) via anagram-frequency restoration against a clean `hawashi`/`muqadamat`/non-garbled vocab (22,560 words), plus manual title overrides. The DB was VACUUMed; `prepare_databases.py` passes, row counts unchanged (3,742 paragraphs).
- **Icons:** re-ran `scripts/make_app_icons.py` from `app/ShiaVerseIcon.png` (512×512 PNG) — 25 files, 746 KiB, deterministic.

No feature or permission was added or removed.

---

## 8) URLs to paste into APKPure

- App icon: upload `app/ShiaVerseIcon.png` (512×512 PNG)
- Privacy policy: `https://mrghalibspcpu.github.io/ShiaVerse/privacy-policy.html`
- Website / Source: `https://github.com/mrghalibspcpu/ShiaVerse`
- Support email: `shiaverse.support@gmail.com`
- Category: Books & Reference
- Age: Everyone
- Requires internet: Yes — for on-demand library download (GitHub) and Qibla map tiles; all reading/search/prayer afterwards is offline.

---

*Prepared on the `arena/a26acbc1-shiaverse` branch from `2f775e4` (1.21.0). Rebuild the APK after merging this branch; do not publish the old 1.21.0 bytes as 1.21.1 — the SHA-256 must be of the patched build.*
