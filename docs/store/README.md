# APKPure submission package — ShiaVerse 1.22.0

| Deliverable | File | State |
|---|---|---|
| Privacy policy (public HTTPS page) | [`../privacy-policy/index.html`](../privacy-policy/index.html) | Written from a code audit. **Not live until GitHub Pages is enabled** (below). |
| Listing text, category, tags, age rating, release notes | [`apkpure-listing.md`](apkpure-listing.md) | Ready for review. |
| 512×512 developer icon (HashTech) | [`assets/hashtech-icon-512.png`](assets/hashtech-icon-512.png) | Ready — the studio's mark, the same file the app shows in **کریڈٹس**. |
| 512×512 app icon | [`assets/shiaverse-icon-512.png`](assets/shiaverse-icon-512.png) | Ready (from `app/ShiaVerseIcon.png`). |
| Dataset sources / rights | [`dataset-rights-audit.md`](dataset-rights-audit.md) | **Open blocker — permission not documented.** |
| Signed release APK + SHA-256 + device test | — | Built by GitHub Actions, not in this package (below). |

## Things only the publisher can do

1. **Enable Pages**: GitHub → repo *Settings → Pages → Deploy from a branch → `main` / `/docs`* (after this branch is merged). The policy URL becomes
   `https://mrghalibspcpu.github.io/ShiaVerse/privacy-policy/` — open it in a browser, confirm it loads, and paste *that* URL into APKPure. (If you publish from the `Shia-Ai` repository instead, the URL is `https://mrghalibspcpu.github.io/Shia-Ai/privacy-policy/`.)
2. **Developer identity — settled for 1.22.0**: developer name **HashTech**
   (Syed Sakhir Hashmi), developer icon
   [`assets/hashtech-icon-512.png`](assets/hashtech-icon-512.png), e-mail
   **sshaashmi@gmail.com**, phone **+923046980280**. These are already on the
   privacy page (`python3 scripts/set_policy_contact.py` was run for the
   address) and inside the app on **سیٹنگز › کریڈٹس**, where both are tappable.
3. **Dataset permission** (see audit) — resolve before upload.
4. **Signing**: the CI keystore is supplied through repository secrets; it was not touched. Keep `applicationId com.shiaai.app` and the same keystore, and the version only goes up (1.22.0+32 > 1.21.1+31 > 1.21.0+30), so installs update in place.

## Building and testing the APK (GitHub Actions)

The push of this branch triggers `.github/workflows/android-apk.yml` (tests + signed release build + pre-release `app-v1.22.0`). Then:

```bash
gh run list --branch arena/47c7311c-shiaverse --limit 3
gh release download app-v1.22.0 -p 'ShiaVerse-1.22.0*.apk'
sha256sum ShiaVerse-1.22.0*.apk
apksigner verify --print-certs ShiaVerse-1.22.0.apk   # fingerprint must equal the one of 1.21.0
```

Device checklist (Android 7.0 / API 24 and a recent version):
- [ ] Update over 1.21.1 keeps data (no "package conflicts" message).
- [ ] Qibla page: map shows streets, no "API key required"; offline → graticule appears.
- [ ] Settings › کریڈٹس: the HashTech mark paints, the e-mail opens the mail app and the number opens the dialler.
- [ ] Settings › ماخذ اور حقوق: the dialog opens and the privacy row reaches the live page once Pages is on.
- [ ] Xplore › روزانہ مطالعہ: pick a track and a length, open today's portion, mark it, restart the app and the mark is still there.
- [ ] Nahj al-Balagha: Khutba 4–11 read correctly **without** re-downloading (the app repairs the old file); after removing and re-downloading, they read identically.
- [ ] Prayer times with GPS on / location denied (IP fallback) / airplane mode.
- [ ] Notification permission prompt (Android 13+), exact-alarm prompt, reminder fires.
- [ ] Cold start with no internet; downloaded books open and search works.

## Also worth doing (not asked, but APKPure/users will notice)

- (Done in 1.21.1) Settings has **Privacy policy** and **Sources & rights**; extend the sources text once the licence permissions are known.
- (Done in 1.22.0) Credits carry the HashTech logo and the studio's e-mail and phone.
- Real device screenshots for the listing; a short "how to download books" first-run hint.
- Existing installs keep the old (garbled) Nahj file until re-downloaded — mitigated in 1.22.0 by the in-app repair (`lib/nahjul_balagha_urdu.dart`). A manifest-hash check that offers "update available" for installed databases is still worth adding.
- `.github/apk-delivery-request` still points at the currently published tag.
