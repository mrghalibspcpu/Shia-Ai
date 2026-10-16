# Production signing and the 1.13.x → store migration plan

Two facts shape this plan:

1. Every APK published so far — including **1.13.1, the version installed on
   the owner's phone** — is signed with the repository's **public CI key**
   (`app/android/ci-signing/shia-library-ci.p12`; fingerprint
   `15:6A:C3:03:…:AF:2D:11`). Its passphrase is in Git on purpose, so this key
   can *stabilise updates* but must **never** sign a public release: anyone
   could craft a malicious "update" over it.
2. Android only installs an update if the new APK is signed with the **same**
   key as the installed one. A production-key build therefore **cannot** be
   installed over 1.13.1 in place; Android will refuse it (no data is touched
   by the refusal — the installed app stays exactly as it is).

Nothing in this plan uninstalls anything, changes the package id, or discards
data on its own. Every destructive step is an explicit, owner-performed action.

## The two release channels

| Channel | Workflow | Key | Purpose |
| --- | --- | --- | --- |
| `app-v<version>` (pre-release) | `android-apk.yml` on every push | public CI key (or owner key if secrets exist) | testing, phone updates within the 1.13.x line, previews |
| `store-v<version>` (release) | `production-release.yml`, manual only | **owner's private key**, enforced | the APK that is uploaded to APKPure/other stores |

`production-release.yml` fails hard when any of the four `ANDROID_*` secrets is
missing (no debug-key, no CI-key fallback), fails if the configured keystore is
the public CI key (certificate fingerprint check), and refuses to overwrite an
existing `store-v*` release. `app/android/app/build.gradle` implements the same
refusal for local builds when `ANDROID_REQUIRE_PRODUCTION_SIGNING=true`.

## Step 0 — generate the private production key (owner, once)

On a machine you trust (your laptop is fine; it never needs to go to Git):

```sh
keytool -genkeypair -v \
  -storetype PKCS12 \
  -keystore shiaverse-production.p12 \
  -alias shiaverse \
  -keyalg RSA -keysize 4096 \
  -validity 10000
```

* Choose strong, unique keystore and key passwords. **If this key is lost,
  future updates to the store release become impossible** — you would have to
  publish a new app listing. Keep at least two offline copies (e.g. an encrypted
  USB drive in two places) of both the `.p12` file and the passwords.
* Record the certificate fingerprint for your own verification:

```sh
keytool -list -v -storetype PKCS12 -keystore shiaverse-production.p12 \
  -alias shiaverse | grep 'SHA256:'
```

* The **only** place the key goes is the GitHub Actions secrets (below) and
  your offline backups. Never commit it, never attach it to an issue/PR/release,
  never paste the passwords into chat.

## Step 1 — put the key in GitHub Actions secrets (owner, once)

> **Note:** the `Production release` workflow is manual
> (`workflow_dispatch`), and GitHub only makes such workflows dispatchable
> once the file is on the repository's **default branch**. After this work is
> merged to `main`, the workflow appears under the Actions tab. Until then it
> is ready and reviewed, but not yet dispatchable.

Repository → **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | output of `base64 -w0 shiaverse-production.p12` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | e.g. `shiaverse` |
| `ANDROID_KEY_PASSWORD` | key password |

Then run **Actions → Production release** with `publish_release: false` first:
it builds, signs, emulator-tests and shows the signer fingerprint in the run
summary **without publishing**. Compare the fingerprint with the `keytool`
output from Step 0. Only when it matches, run again with `publish_release: true`.

## Step 2 — back up the phone's data before the key switch (owner, safe)

The 1.13.2 build (CI-signed, installs **as an update over 1.13.1** — nothing is
uninstalled) adds **ترتیبات → بیک اپ و منتقلی** (Settings → Backup & migrate):

1. Install `ShiaVerse-1.13.2.apk` from the `app-v1.13.2` release. It updates
   1.13.1 in place; books, bookmarks, notes and positions stay.
2. Open **Settings → بیک اپ و منتقلی → بیک اپ محفوظ کریں** and save the JSON
   file somewhere durable (Google Drive, WhatsApp to yourself, a computer).
   The clipboard buttons are a fallback that works without a file picker.
3. The file contains bookmarks, notes, last-read positions, tasbeeh counters
   and wirds, prayer settings, saved location and all preferences — and a list
   of which books were installed. It does **not** contain the ~230 MB of books
   (they re-download) and it never leaves the device unless you save it.

Keep the 1.13.2 APK install around **until the restore has been verified** in
the production build. There is no deadline.

## Step 3 — install the production build (owner, explicit approval required)

Android will not update a CI-key installation with a production-key APK. The
safe sequence is:

1. Make sure the Step 2 backup file exists and opens as JSON
   (`"format": "shiaverse-backup"`).
2. **Uninstall** the old app (only when you decide to switch).
3. Install `ShiaVerse-<store-version>.apk` from the `store-v<store-version>`
   release (or the store build you are about to submit).
4. Open the app → **Settings → بیک اپ و منتقلی → بیک اپ بحال کریں**, pick the
   backup file, confirm. The app lists what will be restored and what must be
   re-downloaded.
5. Re-download the books from **Settings → ڈاؤن لوڈ** (the restore remembers
   which ones you had).
6. Verify: bookmarks, notes, last-read, tasbeeh, prayer settings are yours.

Rollback is always possible: the old `app-v1.13.x` releases stay published
untouched; reinstalling 1.13.2 (CI key) after removing the production build
works the same way, with the same backup file. That is why no `app-v*` release
is ever overwritten.

## What the repo guarantees

* **No secrets in Git, artifacts, or chat.** The keystore is materialised only
  in `$RUNNER_TEMP` on the runner and deleted in an `if: always()` step; the
  workspace paths for owner keys are git-ignored as well.
* **No silent fallback.** Missing production secrets fail the production build
  (Gradle and workflow both). CI builds keep using the public CI key and are
  labelled CI-signed.
* **No overwrites.** `store-v*` releases are immutable; `app-v*` releases are
  never modified by the production workflow.
* **No surprise uninstall/package change.** The package id stays
  `com.shiaai.app`. The uninstall in Step 3 is done by the owner, by hand.

## If the production key is ever lost

Updates for the store release cannot be signed anymore. The options are a new
package id (a different app; users would install it side by side and restore
from backups) or recovering the key from your offline copies. This is why
Step 0 keeps two offline copies of the key and its passwords.
