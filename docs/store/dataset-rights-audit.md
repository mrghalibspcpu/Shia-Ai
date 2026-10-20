# Dataset sources, attribution and reuse rights — honest audit

**Status: rights are NOT cleared for public redistribution.** Nothing below may be
described as "licensed" in a store listing. This file records what the repository
itself documents and what is still unknown. It is not legal advice.

## Where the corpus came from (from the repo's own docs)

`assets/database-manifest.json` names the source as *"Ahadith al Shia Urdu 1.0.1
corpus plus the Quran, Mafatih al-Jinan, and Nahj al-Balagha collections"*, and
`docs/apk-analysis.md` states that the databases were **extracted from a compiled
APK supplied by the owner: package `com.tasneemacademy.jamialahadith`** (Tasneem
Academy / "Jamia al-Ahadith"). The repository contains no licence, permission
letter, or publisher agreement for them. The README says the Nahj database was
later replaced by "the newly uploaded Drive database", also without provenance.

**Consequence.** Unless you (or the person who supplied the files) hold written
permission from Tasneem Academy and the underlying translators/publishers,
republishing these databases through APKPure and GitHub releases is an
infringement risk and can lead to takedown or account action. Get written
permission, or remove/replace the affected databases, before submitting.

## Per dataset

| Dataset (file) | What the repo says about its origin | Underlying work | Rights status |
|---|---|---|---|
| Quran text + Urdu translation + tafsir notes (`quran.db`, 6,236 verses) | Extracted from the Tasneem Academy APK. Translator/tafsir author not recorded in the DB or docs. | Arabic text of the Quran is public domain; the **Urdu translation and tafsir notes are copyrighted works** of their authors/publishers. | **Unknown** — identify the translator/tafsir and obtain permission or swap in an openly licensed translation. |
| 14 hadith books (Al-Kafi, Tahdhib, Faqih, Wasa'il, Kamal al-Din, Khisal, Ma'ani al-Akhbar, Thawab, Tawhid, Mizan al-Hikmah, Ghurar al-Hikam, Hidayat al-Ilm, Hikmat-nama Rasul, Hikmat-nama Imam Husain) | Extracted from the same APK. | Classical Arabic texts are public domain; the **Urdu translations, compilation and editorial apparatus are modern copyrighted works** (e.g. Mizan al-Hikmah, Hikmat-nama titles are modern compilations). Translators/publishers not recorded. | **Unknown / likely restricted.** |
| Mafatih al-Jinan (`mafatihdb-v4.db`) | Same APK. | Arabic duas public domain; Urdu translation copyrighted. | **Unknown.** |
| Sahifa Sajjadiyya (`Sahifa_Sajjadiyya_full_runtime.sqlite3`) | Provenance not documented in the repo. | Arabic public domain; Urdu translation copyrighted. | **Unknown.** |
| Nahj al-Balagha (`nahjul_balagha.db`) | Extracted from the APK, then replaced by a Google-Drive upload; the Urdu translator is not recorded (the Drive file name "Fehmul Fasaha" suggests a published Urdu commentary-translation). 1.21.1 repaired its mirrored text; that does not change authorship. | Sayyid al-Radi's compilation public domain; **Urdu translation/footnotes copyrighted**. | **Unknown.** |
| Twelver Shia encyclopedia (`athna_ashari_encyclopedia.db`) | README: Urdu-Wikipedia articles merged with WikiShia (ویکی شیعہ) notes (`wikishia_urdu_twelver_detailed_notes.sqlite`); each section keeps its source page revision and references. | Wikipedia text is CC BY-SA (plus GFDL on older text); WikiShia's own licence must be read on its site. | **Likely reusable with conditions** (attribution, link to licence, share-alike for the text) — but those conditions are **not yet met in the app**: add a credits screen with page links and licence names. Confirm WikiShia's licence before publishing. |
| Khamenei Urdu fatawa (`khamenei_urdu_fatawa.sqlite`, 428 records) | Collected from the official office site; each row stores `source_url`, `retrieved_at`, a SHA-256 and "verbatim" note. | Official office publications. | **No licence recorded.** Written confirmation from the office that reuse/redistribution is allowed is needed; at minimum keep the visible attribution and source links. |
| Sistani Urdu fatawa (`sistani_urdu_fatawa.sqlite`, 1,619 records) | Collected from sistani.org (`source_url` per row). | Official office publications. | **No licence recorded.** Same as above. |
| Prayer-time maths | `adhan_dart` package. | Open-source library. | Check its licence file (and every other pub.dev dependency's) and list it in app credits. |
| Map tiles | Esri World Street Map; OpenStreetMap Germany. | OSM data is ODbL (© OpenStreetMap contributors); Esri tiles carry Esri terms. | Attribution is shown on the map card. Esri's terms for keyless use of this legacy endpoint are not a signed agreement — treat as best-effort and re-check before relying on it. OSM mirror usage policy: light use only. |
| Icon / logo | User-supplied ShiaVerse plate (`app/ShiaVerseIcon.png`). `tasneemlogo.png` is still in the repo but no longer referenced by the app code. | — | You must own or be permitted to use the plate artwork. Delete the unused Tasneem logo file from the repo. |

## What to do before publishing

1. Ask the data supplier / Tasneem Academy for **written permission** (name of every translator and publisher included). Keep the letter.
2. Extend the in-app **Settings → Sources & rights** dialog (added in 1.21.1, generic wording) to list each work, translator/publisher and licence/permission once known.
3. For anything without permission: ship the app without that database (the manifest/installer design allows each book to be omitted), or replace with an openly licensed source.
4. Never write "licensed", "official" or "authorised" in the listing unless a document proves it.
