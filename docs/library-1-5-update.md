# Library 1.5 — فتاویٰ، آخری مطالعہ اور فوری آغاز

Four changes asked for by readers, all of them local: nothing new leaves the
device except the source links the reader chooses to open.

## 1. Every ruling links back to its source

Both fatawa databases already carried a `source_url` and a `source_ref` per
answer. The reader now surfaces them: each question/answer card ends with the
official address and an **اصل ماخذ پر جائیں** button that opens the marja's own
page in the browser, so a ruling can be verified instead of trusted.

- `Passage` gained `sourceUrl` / `sourceRef`; both come from the same
  `_extraQuery` that feeds the reader, the search hydration and the index.
- `scripts/verify_client_sql.py` fails the build if any answer loses its
  `https://` source or its reference number.
- Links open with `url_launcher` in `externalApplication` mode. They are the only
  outbound requests the app makes.

## 2. One “دینی مسائل (احکام و فتاویٰ)” entry, then pick your marja

The two Urdu fatawa books used to be two nearly identical cards on the home row.
They are now a single collection tile; tapping it opens a marja picker with both
authorities (name, portrait, and the number of rulings), and each one opens its
own category list.

- `models.dart` holds `kFatawaCollectionTitle` and `fatawaBooks`.
- `screens/fatawa_screen.dart` is the picker; it degrades to a download button
  when that marja's database is not installed yet.
- Both books stay separate entries in the download manager — they are two files.

## 3. Sahifa Sajjadiyya stops at 83

`saheefa_data` holds more than the book: besides the supplications it carries the
Imam's biography, "ہمارے بارے میں", lecture-video lists and quiz pages
(`t_id` 5–8, 115–116). Those used to be listed as duas 84 and up.

The reader now shows only `t_id IN (1, 2, 3, 4)`:

| `t_id` | Contents | Count |
|---|---|---|
| 1 | دعائیں صحیفہ سجادیہ | 54 |
| 2 | مزید دعائیں | 7 |
| 3 | ایامِ ہفتہ کی دعائیں | 7 |
| 4 | مناجات خمسہ عشر | 15 |
| | **Total** | **83** |

Row data is untouched — only the query narrows, so 4,318 of the 4,993 rows are
read and indexed. `_countIndexableRows` counts through the same filtered query,
which is what keeps `_indexBook`'s "wrote every row" assertion honest.

## 4. Two kinds of last-seen, and a home screen that opens at once

**Last seen.** `saveLastRead` now writes a `LastReadEntry` (book, record,
section, chapter title, locator, timestamp) twice:

- `last_read_v2` — the global position, shown as **آخری مطالعہ جاری رکھیں** on
  the home screen with the book, the reference (آیت ۱۲ • پارہ ۱, مسئلہ ۱۸۹۴, …)
  and when it was left (آج / کل / date).
- `last_read_book_<key>` — one per book, so the Quran keeps its own surah while
  Mafatih, Sahifa, Nahj al-Balagha and each hadith book keep theirs. Those appear
  under **ہر کتاب کا آخری مقام** on the home screen and as a **جاری رکھیں** card
  at the top of each book, Quran index, Mafatih and Nahj al-Balagha.

Old `book:recordId:sectionId` values are still read on upgrade.

**Instant start.** `initialize()` now takes `buildSearchIndex`. The bootstrap
passes `false`, opens the home screen as soon as the installed books are open,
and then runs `ensureSearchIndex()` in the background. The 96,513-record walk
never blocks the library again: books are readable immediately, and a thin
progress strip (home and search) reports the index catching up. A build that is
interrupted simply resumes next launch.
