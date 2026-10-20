# APKPure submission package — ShiaVerse 1.21.1

| Deliverable | File | State |
|---|---|---|
| Privacy policy (public HTTPS page) | [`../privacy-policy/index.html`](../privacy-policy/index.html) | Written from a code audit. **Not live until GitHub Pages is enabled** (below). |
| Listing text, category, tags, age rating, release notes | [`apkpure-listing.md`](apkpure-listing.md) | Ready for review. |
| 512×512 store icon | [`assets/shiaverse-icon-512.png`](assets/shiaverse-icon-512.png) | Ready (from `app/ShiaVerseIcon.png`). |
| Dataset sources / rights | [`dataset-rights-audit.md`](dataset-rights-audit.md) | **Open blocker — permission not documented.** |
| Signed release APK + SHA-256 + device test | — | Built by GitHub Actions, not in this package (below). |

## Things only the publisher can do

1. **Enable Pages**: GitHub → repo *Settings → Pages → Deploy from a branch → `main` / `/docs`* (after this branch is merged). The policy URL becomes
   `https://mrghalibspcpu.github.io/ShiaVerse/privacy-policy/` — open it in a browser, confirm it loads, and paste *that* URL into APKPure. (If you publish from the `Shia-Ai` repository instead, the URL is `https://mrghalibspcpu.github.io/Shia-Ai/privacy-policy/`.)
2. **Developer name / e-mail**: the policy and listing use the only public identity in the repository (GitHub account `mrghalibspcpu`, issues page). Add your real support address with
   `python3 scripts/set_policy_contact.py you@yourdomain.com`, and enter your real developer name in the APKPure form.
3. **Dataset permission** (see audit) — resolve before upload.
4. **Signing**: the CI keystore is supplied through repository secrets; it was not touched. Keep `applicationId com.shiaai.app` and the same keystore, and the version only goes up (1.21.1+31 > 1.21.0+30), so installs of 1.21.0 update in place.

## Building and testing the APK (GitHub Actions)

The push of this branch triggers `.github/workflows/android-apk.yml` (tests + signed release build + pre-release `app-v1.21.1`). Then:

```bash
gh run list --branch arena/50e97a6e-shiaverse --limit 3
gh release download app-v1.21.1 -p 'ShiaVerse-1.21.1*.apk'
sha256sum ShiaVerse-1.21.1*.apk
apksigner verify --print-certs ShiaVerse-1.21.1.apk   # fingerprint must equal the one of 1.21.0
```

Device checklist (Android 7.0 / API 24 and a recent version):
- [ ] Update over 1.21.0 keeps data (no "package conflicts" message).
- [ ] Qibla page: map shows streets, no "API key required"; offline → graticule appears.
- [ ] Data screen: remove Nahj al-Balagha, re-download, **verify passes**; Khutba 4–11 read correctly.
- [ ] Prayer times with GPS on / location denied (IP fallback) / airplane mode.
- [ ] Notification permission prompt (Android 13+), exact-alarm prompt, reminder fires.
- [ ] Cold start with no internet; downloaded books open and search works.

## Also worth doing (not asked, but APKPure/users will notice)

- Add an in-app **Sources & credits** screen and a link to the privacy policy in Settings.
- Real device screenshots for the listing; a short "how to download books" first-run hint.
- Existing installs keep the old (garbled) Nahj file until re-downloaded: consider a manifest-hash check that offers "update available" for installed databases.
- `.github/apk-delivery-request` still points at 1.21.0.
