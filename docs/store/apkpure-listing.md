# APKPure listing — ShiaVerse 1.22.0

> Publish only after the blockers in [`README.md`](README.md) are cleared (especially
> the dataset-permission question in [`dataset-rights-audit.md`](dataset-rights-audit.md)).

| Field | Value |
|---|---|
| App name | **ShiaVerse** |
| Package | `com.shiaai.app` (keep unchanged — updates depend on it) |
| Version | 1.22.0 (versionCode 32) |
| Min Android | 7.0 (API 24) |
| Category | **Books & Reference** (alt.: Lifestyle) |
| Tags | Shia, Quran, Nahj al-Balagha, Hadith, Al-Kafi, Mafatih al-Jinan, Sahifa Sajjadiyya, Urdu, Qibla, Prayer times, Tasbeeh, Islamic calendar |
| Age rating | **Everyone / 3+** — no ads, no purchases, no user-generated content, no chat. Religious text only; the historical texts mention battles in a scholarly context, nothing graphic. Answer the store's questionnaire the same way. |
| Price | Free, no ads, no in-app purchases |
| Privacy policy URL | `https://mrghalibspcpu.github.io/ShiaVerse/privacy-policy/` — live only after GitHub Pages is switched on (see README) |
| Developer | **HashTech** — Syed Sakhir Hashmi |
| Developer e-mail | **sshaashmi@gmail.com** |
| Developer phone | **+923046980280** |
| Support | **sshaashmi@gmail.com** · **+923046980280** · https://github.com/mrghalibspcpu/ShiaVerse/issues |
| Developer icon | `assets/hashtech-icon-512.png` (512×512 PNG, the HashTech mark) |
| App icon | `assets/shiaverse-icon-512.png` (512×512 PNG, the ShiaVerse plate) |

Both the **developer icon** and the **app icon** are shown on the listing: the
HashTech mark is the studio avatar in APKPure's developer profile, the ShiaVerse
plate stays the app's launcher icon. The same HashTech artwork is bundled in the
APK (`app/assets/images/hashtech.png`) and painted on the **کریڈٹس** card in
**سیٹنگز**, with the e-mail and phone above as tap-to-write and tap-to-call rows
— a reviewer can compare the listing with the installed app in ten seconds.

## Short description (≤ 80 chars)

Urdu Shia library: Quran, Nahj al-Balagha, hadith, prayer times, Qibla, daily study.

## Full description

**ShiaVerse** is a Shia study library for Android with an Urdu interface. It brings the Quran, Nahj al-Balagha, major hadith collections, duas and rulings together with prayer times, a Qibla compass and a tasbeeh counter.

**Inside**
- **Quran** — 114 surahs, 6,236 verses with Urdu translation and tafsir notes.
- **Nahj al-Balagha** — sermons, letters and sayings with Urdu translation, footnotes and introductions.
- **Hadith library** — Al-Kafi, Tahdhib al-Ahkam, Man La Yahduruhu al-Faqih, Wasa'il al-Shia, Kamal al-Din, Al-Khisal, Ma'ani al-Akhbar, Thawab al-A'mal, Kitab al-Tawhid, Mizan al-Hikmah, Ghurar al-Hikam and more, with book → chapter → section navigation.
- **Mafatih al-Jinan** and **Sahifa Sajjadiyya**, and a Twelver Shia encyclopedia.
- **Fatawa** (Urdu) of Ayatollah Khamenei and Ayatollah Sistani, each with a link to its original source page.
- **One search** across everything, bookmarks, notes, reader themes.
- **روزانہ مطالعہ** — a daily portion plan for the Quran or Nahj al-Balagha, with a streak.
- **Prayer times**, Hijri/Islamic calendar, reminders, **Qibla compass** with a street map, **tasbeeh** counter.

**Internet is required for some things — please read**
- The large book databases are **not packaged in the APK**. On first use you download the ones you want from the project's GitHub releases; each file is checked against a SHA-256 fingerprint. Everything together is roughly 240 MB (uncompressed); every book is optional — use Wi-Fi.
- Once a book is downloaded it can be read and searched **without** a connection.
- The Qibla street map, place-name lookup, city search, and the IP-based location fallback need internet.
- Prayer times and the Qibla bearing are calculated on the phone.

**Privacy**
No account, no ads, no analytics. Bookmarks, notes and settings stay on your phone. Location is optional. The app contacts GitHub, map-tile and geocoding services in the situations described in the privacy policy, and those services see your IP address.

**Please note** — Texts and translations are provided for reading and reference. Verify rulings with the original source or a qualified scholar. Compass accuracy depends on your phone's magnetometer; calibrate it (figure-8) if the direction looks off.

## Release notes (1.22.0)

- **روزانہ مطالعہ (daily study)** in Xplore: choose the Quran or a section of
  Nahj al-Balagha and a length of 30/60/90/180 days; the app works out today's
  portion, opens it in the reader and keeps a streak. Works offline.
- **Nahj al-Balagha in readable Urdu**: sermons 4–10 and the scattered reversed
  words are repaired. Installs that still hold the older file are corrected by
  the app itself, and a fresh download from «ڈیٹا» gets the proofread database.
- Home screen: **prayer names are a step larger**, and the **آیت / حدیثِ وقت**
  card now reaches down towards the mini tasbeeh.
- **Credits** carry the **HashTech** logo with tap-to-write e-mail
  (sshaashmi@gmail.com) and tap-to-call phone (+923046980280).
- Qibla map: Esri street tiles with an OpenStreetMap mirror (the previous
  «API key required» image is gone).
- Other fixes and polish.

## Screenshots

Use screenshots taken on a real device from the signed build (APKPure wants at least 3, portrait). Existing mock-ups in `docs/previews/` are not store-quality evidence of the final build.
