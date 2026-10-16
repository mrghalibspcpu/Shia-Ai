# ShiaVerse — Privacy Policy

**App name:** ShiaVerse (Android package `com.shiaai.app`)  
**Developer:** the publisher named on the app's store listing  
**Last updated:** 16 October 2026

ShiaVerse is an offline Shia study library: the Quran with Urdu translation and
tafseer notes, Mafatih al-Jinan, Nahj al-Balagha, Sahifa Sajjadiyya, two fatawa
collections, and fourteen hadith books, with prayer times, a Qibla compass and a
digital tasbeeh. The app was built so that your reading stays on your phone.

This policy describes exactly what the app does and does not do. It applies to
the app distributed by its store listings and by the project's GitHub releases.

## Summary

- **No data is collected by the developer.** There are no accounts, no servers
  of ours, no analytics, no advertising, no crash reporting, and no tracking.
  The app contains no code that sends your bookmarks, notes, reading positions,
  tasbeeh counts, settings, or anything else to any person.
- **Everything is stored on your device** and is removed when you uninstall the
  app (or clear its data). The in-app backup feature lets you save that data to
  a file yourself, so you can restore it later; the file goes only where you
  choose to save it.
- **Internet is optional.** Without internet you can read every installed book.
  Internet is used only for: downloading books you asked for, locating you when
  you ask for prayer times/Qibla, looking up place names, and opening source
  pages you tap.

## What is stored on your device

The app keeps the following locally (in app-private storage and Android
preferences):

- downloaded book databases (re-downloadable content);
- bookmarks and your written notes;
- last-read positions in each book;
- tasbeeh counters and your saved wirds;
- prayer settings (calculation method, Hijri date adjustment, prayer alerts)
  and the location you chose or allowed (a city name and coordinates);
- theme, font and text preferences;
- your recent search words (search history).

None of this leaves the device unless **you** export a backup file and place it
somewhere yourself.

## What is sent over the internet, and to whom

The app has no server of its own. When you use an online feature, the app
contacts these third-party services directly, and only for that feature:

1. **Book downloads (optional).** When you tap to install a book, the app
   downloads a compressed database over HTTPS from the project's GitHub
   releases (`github.com`, `raw.githubusercontent.com`). Interrupted downloads
   resume where they stopped. Every file is checked against a SHA-256 digest
   before it is opened. GitHub's servers see ordinary web-server information
   (such as IP address and user agent), as for any file download.
2. **Approximate location by IP (only if GPS is unavailable and you continue).**
   The app asks `ipapi.co` or `ipwho.is` for a rough location for your IP
   address to suggest prayer times for your area. That provider necessarily
   sees your IP address. The answer is stored on your device like any other
   location.
3. **Place-name lookup (optional).** To turn coordinates into a readable place
   name («G-11، اسلام آباد») or to search for a city you typed, the app sends
   the coordinates or the city name to OpenStreetMap's Nominatim
   (`nominatim.openstreetmap.org`), Open-Meteo's geocoding API
   (`geocoding-api.open-meteo.com`), or BigDataCloud's reverse-geocoding API
   (`api.bigdatacloud.net`). The coordinates or the typed name are all that is
   sent for this lookup.
4. **Source pages in the browser (only when you tap them).** Some fatawa show
   an **اصل ماخذ پر جائیں** button that opens the ruling's original page on the
   marja's official website in your browser. That visit is governed by that
   website's own privacy policy.

The app does **not** send your GPS fix to any of its own systems; coordinates
are used on the device (prayer times and Qibla bearing are computed locally)
and are only shared with the place-name services above, and only when a place
name is being looked up.

## Permissions

- **Location (precise/approximate):** asked at runtime, only to compute prayer
  times and the Qibla direction for where you are. If you refuse, the app
  works fine with a city you pick manually (a built-in offline list) — nothing
  else changes.
- **Internet:** for the optional downloads and lookups described above.
- **Compass sensor:** for the Qibla dial. Sensors need no permission and no
  data is sent anywhere.

The app does not request access to your contacts, files of other apps,
microphone, camera, phone, SMS, or notifications (prayer alerts are in-app
only), and it does not run advertising or analytics SDKs.

## Children

ShiaVerse is a religious library for general audiences. It is not directed at
children under 13 and it knowingly collects no personal information from
anyone, including children.

## Data sharing and sale

There is no data sharing or sale, because no data is collected. The app has no
third-party SDKs that collect data, no advertising networks, and no analytics.

## Security

Book databases are verified against published SHA-256 digests before use, the
app refuses unencrypted (cleartext) connections, and there is no account or
server-side store to breach. A backup file you export contains your bookmarks,
notes and settings — treat it like any personal file when you store it.

## Your choices

- Use the app entirely offline after installing books.
- Decline location permission and choose a city manually.
- Export or delete your data at any time from **ترتیبات → بیک اپ و منتقلی**
  (Settings → Backup & migrate). Uninstalling the app removes all local data.

## Changes to this policy

Any change will be published in this file in the project repository and will
ship with the corresponding app update. The date above shows the latest
revision.

## Contact

Questions about this policy: use the developer contact email shown on the
app's store listing page (the store listing carries the publisher's current
contact address; this policy deliberately does not invent one).
