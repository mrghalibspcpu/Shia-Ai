# Store-readiness audit — ShiaVerse 1.13.2 vs APKPure submission requirements

Audit date: 16 October 2026. This is the factual state of the app in this
repository, checked line by line against the app's own code and against
APKPure's official submission pages. No claim here is aspirational: where
something is missing or unconfirmed it is marked **BLOCKER** or **NEEDS OWNER**.

## A. What APKPure officially requires (current)

Sources: [APKPure developer page](https://apkpure.com/developer.html),
[Submit APK](https://apkpure.com/submit-apk),
[Developer Console guide](https://apkpure.com/howto/how-to-create-apkpure-developer-console-account-for-free).

| Requirement (official) | Source |
| --- | --- |
| Free developer account; profile with developer name, email, website | [console guide](https://apkpure.com/howto/how-to-create-apkpure-developer-console-account-for-free) |
| Submission via [submit-apk](https://apkpure.com/submit-apk) or Developer Console → **Add APPLICATION**; upload under **Manage versions** | [console guide](https://apkpure.com/howto/how-to-create-apkpure-developer-console-account-for-free) |
| File format **APK or XAPK**, max **2000 MB** | [submit-apk](https://apkpure.com/submit-apk) |
| Listing data: app name, package name, **icon, description, screenshots, category** | [console guide](https://apkpure.com/howto/how-to-create-apkpure-developer-console-account-for-free) |
| Manual review by the APKPure team (virus-free + content guidelines); typically 24–48 h; if nothing after **3 business days**, re-check the submission | [developer page](https://apkpure.com/developer.html) |
| Updates: submit with the **same name and APKPure URL** so users get update notifications | [developer page](https://apkpure.com/developer.html) |
| Developer contact for questions: `developer@apkpure.com` | [developer page](https://apkpure.com/developer.html) |

Practical store norms that reviewers expect even where APKPure's own page is
brief (same rules APKPure's copyright/content guidelines enforce): a public
**privacy-policy URL** for an app with location/Internet permissions, an honest
description (no fake claims), screenshots that show the real UI, and the right
to distribute every piece of content you upload.

## B. The app, as it actually is (code audit)

| Item | Current state | Verdict |
| --- | --- | --- |
| App name / launcher label | **ShiaVerse** (`AndroidManifest`) | OK |
| Package id | `com.shiaai.app` — deliberately unchanged (changing it strands every install's data) | OK, keep |
| Version | `1.13.2+19` (`app/pubspec.yaml`); user's phone has 1.13.1+18 | OK |
| minSdk | **24** (Android 7.0) — covers effectively all APKPure devices | OK |
| targetSdk | Flutter stable's `targetSdkVersion` (35/36 depending on the pinned Flutter); no legacy targets | OK for APKPure; Google Play (if ever) needs API 36 + AAB |
| Permissions | `INTERNET`; `ACCESS_FINE_LOCATION` + `ACCESS_COARSE_LOCATION` (runtime-asked, only for prayer times/Qibla). Compass/location hardware are optional hints | OK — declaration text prepared (listing kit) |
| Cleartext traffic | disabled (`usesCleartextTraffic="false"`); all endpoints HTTPS | OK |
| Backup of app data | `allowBackup="false"` (Android auto-backup off — privacy-positive; migration is the in-app backup) | OK |
| Deep link | `shiaai://reader` | OK |
| Ads / accounts / analytics / tracking SDKs | **none** (removed AI layer; no network calls except downloads/lookups) | OK — must be stated honestly in listing |
| App icon | `app/ShiaVerseIcon.png` — already **512×512**; `store/apkpure/icon-512.png` prepared (32-bit PNG) | OK |
| Screenshots | render previews exist; emulator captures are built into the release pipeline; real-device shots recommended | NEEDS OWNER (recommended) |
| Privacy policy | written (EN + UR) from actual code behaviour; in-app screen added | NEEDS OWNER (hosting URL) |
| Listing text (EN + UR) | prepared in `store/apkpure/listing.md`, claims verified against features | OK (owner review) |
| Content rating | questionnaire answers drafted in listing kit (religious content, no violence/gambling, no UGC sharing) | NEEDS OWNER (submit IARC form) |
| Developer contact email | **not invented** — must be supplied by the owner | NEEDS OWNER |
| Signing | 1.13.1 = public CI key | **BLOCKER** for public release — production key pipeline now in place (see below) |

### Network behaviour (verified in code — the basis of the privacy policy)

1. **Book downloads** (optional): HTTPS GET of `database-manifest.json` and
   `<name>.db.gz` from `github.com/mrghalibspcpu/Shia-Ai/releases/download/databases-v1/`,
   then `raw.githubusercontent.com/.../assets/` fallback
   (`app/lib/data_installer.dart`). SHA-256-verified, resumable.
2. **IP location fallback** (only if GPS is unavailable/declined and the reader
   continues): `https://ipapi.co/json/`, fallback `https://ipwho.is/`
   (`app/lib/services/prayer_locations.dart`).
3. **Place naming**: `nominatim.openstreetmap.org` (reverse + search),
   `api.bigdatacloud.net` (reverse), `geocoding-api.open-meteo.com` (city
   search) (`app/lib/services/place_names.dart`).
4. **Fatawa source buttons**: open the stored `source_url` (marja's official
   site) in the external browser (`app/lib/widgets/reader_kit.dart`).
5. Nothing else. No telemetry, no crash reporting, no ad SDKs.

On-device data: downloaded databases, bookmarks, notes, last-read positions,
tasbeeh state/wirds, prayer settings + chosen location, theme/reader prefs,
search history — all in app-private storage/`SharedPreferences`
(`library_repository.dart`, `tasbeeh_controller.dart`, `prayer_controller.dart`,
`prayer_locations.dart`, `reader_kit.dart`, `main.dart`). The 1.13.2 backup
feature (`services/backup_service.dart`) exports exactly this set.

## C. Content and asset redistribution rights

Every store requires you to hold the rights to what you distribute. Status of
each asset in this repository:

| Content | Provenance in repo | Rights status |
| --- | --- | --- |
| Quran Arabic text | supplied SQLite (`assets/quran.db`) | Public-domain sacred text — OK to distribute |
| Urdu translation + tafseer notes (`tr`, `talighe`) | supplied with the database; translator not credited in-repo | **NEEDS OWNER**: identify the translation/tafseer and its licence; modern translations are copyrighted |
| Mafatih al-Jinan (Sheikh Abbas Qummi, d. 1941) | supplied DB | Base text public domain; the Urdu rendering's licence **NEEDS OWNER** confirmation |
| Nahj al-Balagha (Sharif al-Radi, d. 1015) | supplied DB | Base text public domain; translation + 2,352 footnotes are modern — **NEEDS OWNER** confirmation |
| Sahifa Sajjadiyya (83 duas) | extracted from a supplied website build ("site furniture" removed) | **NEEDS OWNER**: confirm the edition/translation may be redistributed |
| Khamenei & Sistani Urdu fatawa | scraped with per-answer `source_url` back to the marja's official site | **NEEDS OWNER**: many marja offices permit non-commercial distribution with attribution — verify for both |
| 14 hadith books (96,513 records) | **extracted from the supplied compiled APK "Ahadith al Shia Urdu"** (`com.tasneemacademy.jamialahadith`) — see `docs/apk-analysis.md` | **BLOCKER-level NEEDS OWNER**: these databases came out of a third party's shipped app. Upload only with written permission from Tasneem Academy (or proof the underlying translations are licensed for redistribution). This is the single largest copyright risk in a store submission. |
| `JameelNooriNastaleeq.ttf` | bundled font | Freeware with unclear redistribution terms — **NEEDS OWNER**: confirm, or swap for an OFL font (e.g. Noto Nastaliq Urdu) before store upload |
| `Amiri-Regular.ttf` | bundled font | SIL OFL — OK with licence notice (add `assets/fonts/OFL.txt` if desired) |
| App icon/artwork (`ShiaVerseIcon.png`, wallpapers, Kaaba PNG) | project artwork / generated by `scripts/make_app_icons.py` | OK if the artwork is yours — **NEEDS OWNER** confirmation |
| Marja portraits (`marja_khamenei.png`, `marja_sistani.png`) | in fatawa UI | Usually tolerated for devotional use; **NEEDS OWNER** confirmation |
| Alert sounds (`.wav`) | generated by `scripts/make_alert_sounds.py` | Self-produced — OK |
| GeoNames-derived `cities.tsv.gz` | bundled place index | GeoNames data is CC-BY — attribution should appear in the listing/about (**NEEDS OWNER**: add credit line) |

## D. Signing — the security core

* **Current (1.13.1 on the phone, and every `app-v*` build):** signed with the
  checked-in CI key `app/android/ci-signing/shia-library-ci.p12`, whose
  passphrase is public. Fine for private testing; **not acceptable for a
  public release** — anyone could sign a fake "update".
* **Production:** the owner generates a private key (runbook:
  `docs/signing-and-migration-plan.md`) and stores it in four GitHub Actions
  secrets. The new `production-release.yml` workflow **fails** when secrets are
  missing — there is deliberately **no fallback** to the CI or debug key — and
  double-checks the signing certificate is *not* the CI key's
  (`15:6A:C3:…:AF:2D:11`). `build.gradle` enforces the same rules for local
  builds with `ANDROID_REQUIRE_PRODUCTION_SIGNING=true`.
* **Key change ⇒ no in-place update over 1.13.1.** Android will reject it
  (harmlessly: the installed app stays). The 1.13.2 bridge release adds in-app
  backup/restore so bookmarks, notes, positions, tasbeeh and settings survive
  the switch; books re-download. No uninstall happens without the owner doing
  it by hand after backing up. Details in the migration plan.

## E. What is ready now vs what is blocked

**Ready in this repository (1.13.2):**

* New version `1.13.2+19` with the backup/migration bridge (updates over
  1.13.1 in place), in-app privacy-policy screen, unchanged features/design.
* Production signing pipeline with hard-fail rules, immutable `store-v*`
  releases, emulator clean-install + launch gate, ZIP + SHA-256 packaging.
* Privacy policy (EN/UR) written from the code's real behaviour; listing kit
  (EN/UR) with description, category, permissions and data-safety declarations;
  512×512 store icon; screenshot candidates + automated emulator captures.
* Publishing checklist: `store/apkpure/SUBMISSION-CHECKLIST.md`.

**Blockers before an APKPure upload (owner action, in order):**

1. **Production key + secrets** (Steps 0–1 of the migration plan), then a
   `publish_release: false` dry run whose signer fingerprint matches your key.
2. **Corpus redistribution rights** — especially the 14-book database set from
   the Tasneem Academy APK, and the modern translations/tafseer. Do not upload
   to any store until this is settled in writing. (The GitHub releases so far
   are the owner's private distribution channel; a store is public distribution
   and raises the bar.)
3. **Privacy-policy hosting URL** (e.g. enable GitHub Pages on `docs/`, or any
   HTTPS host you control) and **your contact email** for the listing.
4. **Your phone's final verification** of the production build (install +
   restore + launch). Until you confirm, nothing is "verified on device".
5. **Your explicit approval** — nothing gets submitted to APKPure without it.

Nothing in the existing `app-v1.13.1` (or older) releases was modified or
overwritten by this work.
