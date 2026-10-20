# Wallpaper, continuous Mushaf and compass update (1.13.0+17)

- The five-button home dock is black **behind** the coloured keys and under the
  navigation gesture area; labels are still outside the keys. The rail, five
  collection tiles and dock keys get a rounded specular highlight, layered
  gradient, rim and depth shadow. No navigation action was moved.
- The mini prayer row is bottom-aligned on its animated sky. On tall phones the
  ayah/hadith card consumes the dial's otherwise empty space, bringing its
  bottom to within a small row gap of the tasbeeh's top. Location, countdown,
  saved tasbeeh and controls are unchanged.
- The detailed prayer screen uses **its own** mosque photograph
  (`prayer_details.jpg`), while the home card still uses its four animated skies.
  Weekday, Gregorian and adjustable Hijri dates, place, location detail,
  coordinates, live time and the tasbeeh shortcut are actual widgets above the
  wallpaper — no date is baked into the JPEG.
- Quran index entries and chapter-name containers in hadith/Sahifa/fatawa,
  Mafatih and Nahj al-Balagha use `ChapterWallpaperCard`. Its parchment is ink
  **inside each card**, not a page/reader wallpaper; tapping still ripples.
- Quran top controls have visible names (**جائیں**, **ترتیبات**). The index also
  has a labelled page jump and a direct **مصحف موڈ** entry. The reader toggle is
  reversible and remembers its own `quran_mushaf_mode_v1` flag. Mushaf groups
  verses by existing Quran page (and surah) into lazy, selectable, justified
  **continuous Arabic matn** with ayah markers. No per-ayah card, Urdu
  translation, tafseer or footnotes are created in this mode. The original
  study cards, bookmarks, notes, copy, search highlighting, surah/juz/page
  loaders, jump target and font/palette preferences remain untouched; a search
  result starts in study mode even when Mushaf was saved as the default.
  Quran verse one already contains Bismillah in the corpus, so Mushaf does not
  add a second copy. A target splits its page flow immediately before that
  verse, keeping jump-to-ayah exact rather than landing only on the page.
- Nahj al-Balagha's division label and displayed database headings use
  **خطبات**, not the old **خطب**. Source prose and saved identifiers are not
  rewritten; words like **خطبہ** remain unchanged.
- Qibla keeps the same live sensor, smoothing and bearing calculation. Its
  inset, engraved three-dimensional dial now carries a small isolated Kaaba
  PNG marker that rotates *around* the rose but remains upright. The artwork
  is bundled offline, not downloaded from a third-party service.

The three new image assets were generated for this app and downsampled; the
Kaaba has an actual alpha channel. No corpus or Android signing material was
changed. Widget tests guard the new layout, Mushaf flow/toggle/persistence,
chapter wallpaper scope, prayer wallpaper and compass marker. CI runs Flutter
analysis/tests and publishes a verified signed APK and zipped APK on push.
