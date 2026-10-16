# Store screenshots (candidates)

Real UI of the app, rendered by `app/test/ui_layout_test.dart` at the app's own
measurements (same widgets the phone shows — not mockups). Captured from the
1.13.x build; the dashboard/readers/prayer/Qibla/tasbeeh screens shown here are
unchanged in 1.13.2.

| File | Screen |
| --- | --- |
| `01-home-dashboard.png` | Home dashboard (824×1830) |
| `02-quran-translation.png` | Quran reader — Arabic + Urdu translation |
| `03-mushaf-mode.png` | مصحف موڈ — continuous Arabic-only Mushaf |
| `04-prayer-times.png` | Prayer times (hero + day times + Qibla strip) |
| `05-qibla-compass.png` | Qibla compass with the Kaaba dial |
| `06-tasbeeh.png` | Tasbeeh-e-Zahra (s.a.) full counter |
| `07-city-picker.png` | City picker (offline list + search) |
| `08-home-dawn.png` | Home with the dawn prayer-card sky |

* APKPure: upload 4–8 of these as-is.
* The production release pipeline also captures clean-install screenshots from
  the signed release build on an Android 15 emulator (`store-shots/` in the
  workflow artifacts) — use those or your own phone's screenshots if you
  prefer device-faithful status bars before submitting.
* If a store enforces a maximum 2:1 height-to-width ratio, trim
  `01-home-dashboard.png` and `06-tasbeeh.png` from the bottom or add thin
  side borders; APKPure itself accepts these sizes.
