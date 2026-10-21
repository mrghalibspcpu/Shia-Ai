# روزانہ مطالعہ — several books at a time (1.24)

**Xplore Xtra → روزانہ مطالعہ** turns the library into a habit. The reader
picks the books to work through, picks a length in days, and the app works out
today's portion of every one of them, opens the reader at exactly that page or
entry, and counts the streak. Nothing is downloaded and nothing leaves the
phone — the portion is pure arithmetic over the book's own length, so it keeps
working offline forever.

## More than one book

A plan names one book or several. The picker (`_PlanBuilder`) is a
multi-select: the Quran (ختمِ قرآن) and the three sections of Nahj al-Balagha
(خطبات، خطوط، حکمت) can be studied together, and each one gets its own
portion of the day.

The plan keeps the book it was started with in `track` and the rest in
`extraTracks`; `tracks` returns the two together and `isMultiBook` says
whether more than one is named. The plan is stored as JSON under
`daily_study_plan_v1`, and a plan written by the older single-book version
still loads — it simply has no `extraTracks`.

Each book of the plan gets its own card in the plan view: the Quran's card
counts mushaf pages, a Nahj card counts the entries of its section. A book
whose text is not installed is left out of the day's work with a notice
instead of a broken card.

## The reader walks on

Opening a book from the plan opens the **whole run** of the day's portion,
not only its first page:

- the Quran opens at `QuranPageReaderScreen(page: …, lastPage: …)`, and the
  page list loads every page of the run in one go;
- Nahj al-Balagha opens at `BalaghaReaderScreen(typeNo: …, lastTypeNo: …)`,
  and the reader loads every entry of the run.

At the end of a run the reader offers where to go next, in the reader's own
footer:

- **the surah before and the surah after** the pages on the screen
  («پچھلا سورہ» / «اگلا سورہ») — the surah the pages start in, and the one
  after the surah they end in;
- **the run of pages before and after** this one («پچھلا صفحہ» /
  «اگلا صفحہ»), stepping by the length of the run itself, so a reader who
  wants more simply continues into the next run.

The same is true of Nahj al-Balagha: at the end of the entries of the day, the
reader offers the entry before and the entry after.

## The streak

The streak counts the days, not the books: a day counts once it has been
marked done, whatever the reader read that day. The completed days are stored
with the plan, so the counter survives a restart of the app.

## The features that do not exist yet

The rest of Xplore Xtra — the other three entries of the section — is shown as
plain **«جلد آ رہا ہے»** containers. Nothing else is written about them: a
feature that is not there yet is described by its absence, not by a promise in
a card.
