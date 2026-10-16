# ShiaVerse — APKPure publishing checklist

Run order matters. Items marked **[OWNER]** need the publisher; items marked
**[APPROVAL]** must not happen without the publisher's explicit go-ahead.
Nothing here has been submitted anywhere — this file is the map.

## Phase 0 — blockers to settle first

- [ ] **[OWNER] Corpus redistribution rights.** In writing: permission to
  distribute the 14 hadith databases (extracted from Tasneem Academy's
  compiled app) and the modern Urdu translations/tafseer (Quran, Mafatih,
  Nahj al-Balagha, Sahifa, fatawa). See the rights matrix in
  `docs/store-readiness-audit.md` §C. **Do not upload to any store until this
  is settled.**
- [ ] **[OWNER] Font licence:** confirm Jameel Noori Nastaleeq may ship in a
  public app, or switch to an OFL font (e.g. Noto Nastaliq Urdu).
- [ ] **[OWNER] Support email** for the listing and the privacy policy contact
  (a real address you control — none is invented in these documents).
- [ ] **[OWNER] GeoNames attribution:** add a credit line ("Place names based
  on GeoNames data, geonames.org, CC-BY") to the listing/about section.

## Phase 1 — production signing key (never in Git/chat)

- [ ] **[OWNER] Generate the private key** (Step 0 of
  `docs/signing-and-migration-plan.md`); store two offline copies of the key
  and passwords. `keytool` fingerprints recorded.
- [ ] **[OWNER] Add the four GitHub Actions secrets**
  (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
  `ANDROID_KEY_PASSWORD`) — Settings → Secrets and variables → Actions.
- [ ] Run **Actions → Production release** with `expected_version` =
  `pubspec` version and `publish_release: false`. It must pass: secrets gate,
  CI-key refusal, tests, build, emulator clean-install + launch.
- [ ] Check the run summary: the **signer fingerprint matches your keytool
  fingerprint** and is not `15:6A:C3:…:AF:2D:11`.

## Phase 2 — the migration bridge (safe for the phone)

- [ ] Install `ShiaVerse-1.13.2.apk` from release `app-v1.13.2` **over** the
  installed 1.13.1 (in-place update; no uninstall, no data loss).
- [ ] **[OWNER] Export a backup:** Settings → بیک اپ و منتقلی → بیک اپ محفوظ
  کریں. Keep the JSON file on Drive/PC/WhatsApp. Confirm it contains your
  bookmarks/notes (open it and look for `"format": "shiaverse-backup"`).
- [ ] Verify the 1.13.2 update kept everything (books open, last-read intact).

## Phase 3 — the store build

- [ ] Bump `app/pubspec.yaml` to the store version (e.g. `1.14.0+20`) and push
  (a normal `android-apk` run tests it on the CI channel first).
- [ ] Run **Production release** again with `publish_release: true` for that
  version. Artifacts: `ShiaVerse-<v>.apk`, `ShiaVerse-<v>.zip`, `SHA256SUMS.txt`,
  listing screenshots — on the immutable `store-v<v>` release.
- [ ] Verify the download: `sha256sum -c SHA256SUMS.txt` matches the release
  notes.
- [ ] **[OWNER] Phone test of the production APK:**
  1. (only when you decide) uninstall the CI-signed app;
  2. install `ShiaVerse-<v>.apk`;
  3. restore the backup; re-download books;
  4. check bookmarks/notes/positions/tasbeeh/prayer settings.
  **[APPROVAL]** — until the owner says this passed, the build is *not*
  "verified on device".

## Phase 4 — listing (APKPure Developer Console)

- [ ] **[OWNER] Register** at https://developer.apkpure.com/ (name, email,
  website).
- [ ] **Add application** → name `ShiaVerse`, package `com.shiaai.app`.
- [ ] Paste listing text from `store/apkpure/listing.md` (short + full
  description, EN and/or UR), category **Books & Reference**, price **Free**.
- [ ] Upload icon `store/apkpure/icon-512.png` and 4–8 screenshots
  (`store/apkpure/screenshots/` + the pipeline's `store-shots/`).
- [ ] **[OWNER] Publish the privacy policy** at a public HTTPS URL — quickest:
  Settings → Pages → deploy from `docs/` — and paste the URL into the listing
  and the form. (The in-app screen already links to the repository copy.)
- [ ] Permissions/data section: use the declarations in `listing.md`.
- [ ] Content rating questionnaire: answer per the IARC draft in `listing.md`.
- [ ] **Manage versions** → upload `ShiaVerse-<v>.apk` (APK, < 2 GB).
- [ ] **[APPROVAL] Submit for review** — only after the owner's explicit
  approval. Review is manual (24–48 h typical; if nothing in 3 business days,
  re-check against the guidelines; APKPure dev contact: developer@apkpure.com).

## Phase 5 — after approval

- [ ] Record the app's APKPure URL; later updates must be submitted with the
  same name and URL (that is how APKPure notifies users).
- [ ] Keep `store-v*` releases immutable; every store update is a new version
  built by **Production release**.
- [ ] Never re-use or overwrite `app-v1.13.1` or older releases.

## What is required from the owner (short list)

1. Rights confirmations (corpus, translations, fonts, portraits, artwork).
2. Real support email.
3. Private signing keystore + the four GitHub secrets (runbook in
   `docs/signing-and-migration-plan.md`).
4. Publish/host the privacy policy URL.
5. Backup export on the phone before any uninstall.
6. Final on-device verification of the production APK.
7. Explicit approval before the APKPure submission (and for any other store).
