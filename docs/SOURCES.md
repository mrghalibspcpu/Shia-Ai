# ShiaVerse — Dataset Sources, Attribution & Reuse

This file is the audit required for APKPure / Play “Sources & attribution”. Every file below was checked on disk (`assets/*.db`, `app/assets/geo/cities.tsv.gz`) and against the manifest (`assets/database-manifest.json`, 21 DBs, format v2, page_size 1024).

## Summary table

| # | Collection | SQLite file(s) | Rows (manifest) | Origin | License / rights | What to show to the user |
|---|---|---|---|---|---|---|
| 1 | Quran — Arabic + Urdu tarjuma & tafseer | `quran.db` (16.9 MB) | 6,236 verses, 114 surahs, juz/page locators | Public scripture + the Urdu translation/notes shipped with “Ahadith al Shia Urdu 1.0.1”. Checked into `main` as `assets/quran.db`. | Quranic Arabic is public domain; Urdu notes are “as provided” — keep verse locator (surah:ayah, juz, page) and do not claim ownership. | `formatCitation(book, chapter, locator, page)` |
| 2 | Mafatih al-Jinan | `mafatihdb-v4.db` (9.1 MB) | 677 items, 5,378 lines, 6 chapters | Shaykh Abbas Qummi, public domain compilation. | Public domain as classical work; DB packaging is app-internal. | Cite `M_items`/`Lines` title, `L_Translate` when present. |
| 3 | Nahj al-Balagha | `nahjul_balagha.db` (6.5 MB) | 3,742 paragraphs, 810 headings, 2,352 hawashi, 504 muqadamat | Sayyid al-Radi (c. 400 AH), public domain; Urdu translation is the “Drive-uploaded” corpus noted in README 1.21, normalized to 1 KiB pages by `scripts/normalize_databases.py` (fixed khutbas 4–11 in this branch). | Arabic public domain; Urdu as-provided. Do not present as newly licensed translation. | Show `AR` + `UR` + expandable `hawashi` (footnote) — now readable after anagram fix. |
| 4 | Sahifa Sajjadiyya | `Sahifa_Sajjadiyya_full_runtime.sqlite3` (2.7 MB) | 4,993 rows, 83 supplications used | Imam al-Sajjad, public domain. | Same as above. | 83 duas, `saheefa_data`/`saheefa_index`. |
| 5 | Fatawa — Khamenei | `khamenei_urdu_fatawa.sqlite` (1.4 MB) | 428 Q/A, 35 categories | Scraped from the official Urdu site for `khamenei_urdu_fatawa`, one `source_url` per answer, with `source_ref`. | **Per-answer link must be kept** — the reader shows “اصل ماخذ پر جائیں — مسئلہ …” + URL. Attribute the marja; do not re-publish as your own ruling. Check `robots.txt` before external re-hosting. | `question_ur` / `answer_ur` + `source_url` button. |
| 6 | Fatawa — Sistani | `sistani_urdu_fatawa.sqlite` (3.7 MB) | 1,619 Q/A, 245 categories | Same as above for `sistani`. | Same requirement. | Same. |
| 7 | 14 hadith books | `shia-databases.zip` (43 MB gz / 222 MB expanded) → `alkafi.db` … `wasail.db` | 96,513 Parags, 17,855 Sections, 845 Chaps | “Ahadith al Shia Urdu 1.0.1” corpus (`base.apk` → `assets/flutter_assets/assets/databases/`). Classical Shia hadith texts (Al-Kafi, Tahdhib, etc.) are public domain as historical works. | DB packaging is not a new copyright; cite book title + chapter/section + page (`Parags.paganum`), never the internal `Parags.ID` as a hadith number. | `formatCitation` with book + chapter + section. |
| 8 | Athna-Ashari Encyclopedia (Twelver) | `athna_ashari_encyclopedia.db.gz` (2.4 MB gz / 10.6 MB db) | 574 articles, 3,320 sections, 8,142 refs, 12 Imams, 6 topics | **Urdu Wikipedia** curated dump “اثنا عشری انسائکلوپیڈیا (منتخب).zip”, built by `scripts/build_encyclopedia_db.py`. Every `sections` row keeps `source_url` + `history_url` with `oldid` revision. | **CC BY-SA 4.0** — the only collection with an explicit share-alike license. Wikishia notes merged in 1.20 were *removed* in 1.21 because source pages weren’t reachable; now every “ماخذ” link is `ur.wikipedia.org` with revision. | Keep per-section “ماخذ” chip, article-closing “ماخذ و حوالہ جات” and `related_articles` only to contained articles. Link to `https://creativecommons.org/licenses/by-sa/4.0/`. |
| 9 | GeoNames city index | `app/assets/geo/cities.tsv.gz` (1.3 MB, 73k places) | Offline reverse-geocoding & search | GeoNames `cities5000`, CC BY 4.0 (`scripts/build_city_index.py`). | Attribute GeoNames. | Used for “GPS se maqam taza karein” labeling without network. |

### Reproduction

```sh
python3 scripts/prepare_databases.py          # manifest vs on-disk
python3 scripts/verify_corpus.py              # open every DB, row counts, spot checks
python3 scripts/verify_client_sql.py          # replay Dart SQL
python3 -m unittest discover -v               # manifest + standalone DB specs
```

All three passed on 2026-10-20 after the Nahj fix (21 DBs, `page_size` 1024).

## What not to claim

- Do not list an unverified Urdu translation as “CC BY-SA” or “public domain” without checking its publisher. The policy page says “as provided in the corpus” for those.
- Do not present fatawa without their `source_url`; the per-answer link is the audit trail.
- Do not advertise “all content offline included” — the 14-book corpus + encyclopedia are *downloaded* from GitHub on first use (≈53 MB gzipped). State: “Internet required for initial library download; all reading/search/prayer afterwards is offline.”

## Third-party code & assets

- `adhan_dart` 2.0.1 (Dart port of `adhan-js`, MIT) — Jafari/Leva-Qum prayer calc.
- `cities.tsv.gz` — GeoNames CC BY 4.0.
- Wallpapers (`wall_qibla.jpg` etc.) and `prayer_hero.jpg`, `sky_*.jpg` — shipped in `app/assets/images/`, cropped to 900×1600, listed in `pubspec.yaml`.
- Audio chimes (`chime_*.wav`, `shiaverse_prayer_chime.wav`) — synthesized via `scripts/make_alert_sounds.py`, ~130 kB total.
- Fonts `JameelNooriNastaleeq.ttf` + `Amiri-Regular.ttf` — bundled for Urdu/Arabic rendering.

## Publisher note for APKPure

If you re-host these texts outside ShiaVerse, keep the per-collection citations above and respect the Wikipedia CC BY-SA 4.0 requirement for the encyclopedia. For the other classical texts, no new rights are claimed; cite the classical author and the verse/locator.
