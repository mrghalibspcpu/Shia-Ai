# ShiaVerse on APKPure — listing kit

Everything the APKPure upload form asks for, in one place. The developer
identity is **HashTech** and its artwork is
[`hashtech-apkpure-512.png`](hashtech-apkpure-512.png) — the same file the app
ships as `app/assets/images/hashtech.png` and shows in **سیٹنگز › کریڈٹس**.

## Developer identity (APKPure → Account → Developer profile)

| Field | Value |
|---|---|
| Developer name | **HashTech** |
| Developer icon / avatar | `docs/store/hashtech-apkpure-512.png` (512 × 512 PNG) |
| Email | **sshaashmi@gmail.com** |
| Phone | **+923046980280** |
| Website | the repository page: `https://github.com/mrghalibspcpu/ShiaVerse` |
| Privacy policy | `docs/store/privacy-policy.md` |
| Country | Pakistan |

The same e-mail and number are printed inside the app, in
**سیٹنگز › کریڈٹس**, as tappable `mailto:` and `tel:` rows — a reviewer can
compare the two without leaving the phone.

## App identity (APKPure → Upload APK)

| Field | Value |
|---|---|
| App name | **ShiaVerse — شیعہ ورس** |
| Package name | `com.shiaai.app` |
| Version name | `1.22.0` |
| Version code | `31` |
| Category | Books & Reference (secondary: Education) |
| Content rating | Everyone / 3+ (no ads, no user-generated content) |
| Price | Free |
| Ads | **No** |
| In-app purchases | **No** |
| Signing | the checked-in CI key (`app/android/ci-signing/`), or the owner's
  release key when the `ANDROID_*` secrets are set — see
  `app/android/ci-signing/README.md` |

The APK to upload is the **universal** build from the *Android APK* workflow
(`ShiaVerse-<version>-universal.apk`). The per-ABI splits are smaller but cannot
be installed through a store that serves one file per device profile; APKPure
accepts the universal build as a single APK and, if the splits are uploaded too,
uses them as the ABI-specific variants.

## Short description (80 characters max)

```
Offline Shia library: Quran, Nahj al-Balagha, Mafatih, 14 hadith books, prayer times.
```

Urdu (for the localized listing):

```
قرآن، نہج البلاغہ، مفاتیح الجنان اور چودہ کتبِ احادیث — مکمل آف لائن، نماز کے اوقات اور قبلہ نما کے ساتھ۔
```

## Full description (English)

```
ShiaVerse is a complete offline library for the followers of the Ahl al-Bayt (a.s.):
the Holy Quran with Urdu translation and commentary, Nahj al-Balagha (sermons,
letters and short sayings), Mafatih al-Jinan with its supplications and rituals,
Sahifa Sajjadiyya, fourteen hadith collections, and Shia (Jafari) jurisprudence
answers — all on the phone, without a connection.

READ
• Quran: surah, juz, page and mushaf views with Urdu translation
• Nahj al-Balagha: 241 sermons, 79 letters, 480 sayings, with footnotes
• Mafatih al-Jinan: 677 supplications and practices
• Fourteen hadith books: Al-Kafi, Wasail, Tahzeeb, Mizan al-Hikmah and more
• Fatawa from Ayatollah Sistani and Ayatollah Khamenei (Urdu)
• One search across every book, working entirely offline

PRAY AND REMEMBER
• Shia (Jafari) prayer times for your own location, with the next prayer on the
  home screen and optional alerts
• Live Qibla compass with a street map and an offline bearing diagram
• Digital tasbeeh with Tasbeeh-e-Zahra (s.a.), your own wird and a daily goal
• Crescent sighting and the Islamic calendar

READ YOUR WAY
• Bookmarks, notes, last-read markers and whole-surah bookmarks
• Urdu and Arabic typefaces, font size, light, dark and AMOLED themes
• آیت / حدیثِ وقت — a verse or narration chosen for the moment
• روزانہ مطالعہ — a daily portion plan that finishes a whole book

NO ACCOUNTS. NO ADS. NO TRACKING.
The library is stored on the device; the app only reaches the network when you
ask it to download a collection or refresh the prayer location.

Developer: HashTech — sshaashmi@gmail.com — +923046980280
```

## Full description (Urdu)

```
شیعہ ورس اہلِ بیت (علیہم السلام) کے پیروکاروں کے لیے ایک مکمل آف لائن لائبریری ہے:
قرآنِ کریم اردو ترجمہ و تفسیر کے ساتھ، نہج البلاغہ (خطبات، خطوط، حکمت)، مفاتیح الجنان
کی دعائیں و اعمال، صحیفہ سجادیہ، چودہ کتبِ احادیث اور فقہی مسائل — سب کچھ آپ کے فون میں،
انٹرنیٹ کے بغیر۔

پڑھیں
• قرآنِ کریم: سورت، پارہ، صفحہ اور مصحف کے انداز میں، اردو ترجمے کے ساتھ
• نہج البلاغہ: ۲۴۱ خطبات، ۷۹ خطوط اور ۴۸۰ اقوالِ قصار، حواشی کے ساتھ
• مفاتیح الجنان: ۶۷۷ دعائیں اور اعمال
• چودہ کتبِ احادیث: الکافی، وسائل، تہذیب، میزان الحکمہ وغیرہ
• آیت اللہ سیستانی اور آیت اللہ خامنہ ای کے اردو فتاویٰ
• پوری لائبریری میں ایک تلاش، مکمل طور پر آف لائن

نماز اور ذکر
• آپ کے مقام کے مطابق اہلِ تشیع (جعفری) اوقاتِ نماز، اگلی نماز ہوم اسکرین پر
• لائیو قبلہ نما، سٹریٹ میپ اور آف لائن نقشے کے ساتھ
• ڈیجیٹل تسبیح: تسبیحِ زہرا (س)، اپنا ورد اور روزانہ کا ہدف
• چاند کی رویت اور اسلامی تقویم

اپنی طرز پر پڑھیں
• بک مارکس، نوٹس، «جہاں چھوڑا تھا وہیں سے»، مکمل سورت کے بک مارکس
• اردو و عربی خط، فونٹ سائز، لائٹ، ڈارک اور AMOLED تھیمز
• آیت / حدیثِ وقت — وقت کے مطابق ایک آیت یا روایت
• روزانہ مطالعہ — روز کا مقررہ حصہ، تاکہ کتاب مکمل ہو

نہ اکاؤنٹ، نہ اشتہار، نہ ٹریکنگ۔
لائبریری آپ کے فون میں محفوظ رہتی ہے؛ ایپ صرف اُس وقت انٹرنیٹ سے رابطہ کرتی ہے جب آپ
کوئی مجموعہ ڈاؤن لوڈ کریں یا اپنا مقام تازہ کریں۔

ڈویلپر: HashTech — sshaashmi@gmail.com — +923046980280
```

## Graphic assets

| Asset | File | Notes |
|---|---|---|
| Developer icon | `docs/store/hashtech-apkpure-512.png` | 512 × 512, the HashTech mark |
| App icon | `app/assets/images/shiaverse_icon.png` | the app's own launcher plate |
| Screenshots | `docs/previews/*.png`, `docs/previews/*.jpg` | phone screenshots of the home screen and readers, produced by `app/test/ui_layout_test.dart` (`SHIAVERSE_PREVIEW_DIR`) |
| Feature graphic | `app/assets/images/prayer_hero.jpg` | 16:9 crop works for APKPure's header slot |

## Rating and permissions to declare

The app requests: internet (to download a collection), notifications (prayer
alerts), exact alarms (so a prayer alert is not deferred), location (prayer
times and Qibla), and the compass sensor (declared `required="false"`). It
does not request storage, contacts, camera, microphone or advertising IDs.
