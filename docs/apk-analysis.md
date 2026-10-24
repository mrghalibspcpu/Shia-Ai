# APK and database inventory

The uploaded three-volume archive was read from the repository's `main` branch without switching this working branch. The 7z volumes were concatenated and inspected; they contain an XAPK-style stream with these entries:

- `base.apk`
- `icon.png`
- `split_config.arm64_v8a.apk`
- `split_config.en.apk`
- `split_config.ur.apk`
- `split_config.xxhdpi.apk`

The split APKs are required together for a complete install. The ARM64 split contains `libapp.so` and `libflutter.so`; it is not a standalone source project.

## App metadata observed in `base.apk`

- Label: **Ahadith al Shia Urdu**
- Package: `com.tasneemacademy.jamialahadith`
- Version: `1.0.1` (version code `7`)
- Flutter embedding v2; Flutter AOT code is in the ABI split
- `minSdkVersion=24`, `targetSdkVersion=36`
- Android Gradle Plugin metadata: `8.7.3`
- The manifest includes Google Play split-install and license-check metadata.

This confirms we received compiled APKs, not the Flutter source tree. `libapp.so` is ahead-of-time compiled Dart code; the APK does not contain the original `lib/*.dart`, `pubspec.yaml`, Gradle project, or build scripts. The `CHECK_LICENSE`/Play distribution metadata and signing certificate also mean a newly signed APK cannot be assumed to update or behave like the Play-installed app. No protection or license check has been patched.

## Database inventory

`base.apk` contains 14 SQLite files under `assets/flutter_assets/assets/databases/`. The data is bilingual: `Parags.txt` carries Arabic text and `Parags.mean` carries Urdu translation. Each book database uses the same core navigation tables:

- `Parags(ID, txt, Secid, paganum, mean, ...)` — record text and reader locator.
- `Sections(ID, title, Chapid, Secid)` — section heading.
- `Chaps(ID, cid, title, bookid)` — chapter heading.

`Parags.Secid` maps to `Sections.Secid`, and `Sections.Chapid` maps to `Chaps.cid`. Some introductory rows have blank section IDs, so callers must tolerate a missing section instead of dropping the record. Record IDs are database-local; a locator must include the database/book key as well as the paragraph ID.

All 14 extracted databases passed SQLite `PRAGMA quick_check`. Counts from the supplied APK:

| Database | Paragraphs | Sections | Chapters |
|---|---:|---:|---:|
| `Tahzeeb.db` | 8,239 | 267 | 7 |
| `alkafi.db` | 8,032 | 1,183 | 19 |
| `alkhisal.db` | 1,257 | 964 | 26 |
| `hakam.db` | 5,873 | 46 | 16 |
| `hidaya.db` | 11,052 | 722 | 28 |
| `hikmatprophet.db` | 4,445 | 2,087 | 11 |
| `imam.db` | 860 | 184 | 11 |
| `kamaledeen.db` | 668 | 91 | 2 |
| `maniakbar.db` | 801 | 431 | 2 |
| `manlahyahzur.db` | 6,003 | 694 | 5 |
| `mezan.db` | 20,335 | 3,599 | 497 |
| `swab.db` | 1,132 | 612 | 3 |
| `towheed.db` | 584 | 69 | 2 |
| `wasail.db` | 27,232 | 6,906 | 216 |
| **Total** | **96,513** | **17,855** | **845** |

The compressed bundle `assets/shia-databases.zip` preserves the source databases without checking in the expanded files. Run `python3 scripts/prepare_databases.py` to validate every database against `assets/database-manifest.json`, or add `--output app/assets/databases` to bundle them into the APK. Three further collections (`quran.db`, `mafatihdb-v4.db`, `nahjul_balagha.db`) are checked in directly and normalised by `scripts/normalize_databases.py`; the manifest covers all 17 files with sizes, SHA-256 hashes, row counts, and download locations.

## Client rebuild and remaining limitations

The original Flutter source is not present, so the repository now contains a from-scratch Flutter client under `app/`; it is a clean rebuild, not a decompilation or a patch to the supplied APK. It uses the preserved databases and reader locators to provide a book → chapter → section hierarchy for the 14 hadith books, dedicated Quran/Mafatih/Nahj al-Balagha readers, one full-text search across all 17 databases, bookmarks, notes, and reader themes. An AI chat layer existed in an earlier revision and was removed; the current client reintroduces a separately designed, source-grounded "ShiaAi" question/answer flow (see `docs/shia-ai.md`). ShiaAi retrieval runs entirely on the device over the installed databases, and online synthesis is opt-in, off by default, and sends only short retrieved excerpts to a self-hosted gateway that holds the Gemini API key server-side — no key is shipped in the APK. Apart from that opt-in flow and the optional corpus download, the client is fully offline. Similarity to undocumented parts of the original UI or feature set cannot be guaranteed.

The Flutter app registers the `shiaai://reader` route and resolves its book/record locator locally. The Android package ID for this rebuild is `com.shiaai.app`, not the supplied package ID `com.tasneemacademy.jamialahadith`. A fresh signature/package cannot be assumed to replace the Play-installed app. Preserve the original owner keystore and any Play licensing requirements; this project does not patch or bypass licensing checks. Do not put a signing key or any credential in Git/chat.
