# CI signing key

`shia-library-ci.p12` is the key every **CI build** (`.github/workflows/android-apk.yml`)
signs the APK with, so that successive builds installed from download links
**update over each other**.

## Why this exists

GitHub's build runners generate a fresh Android debug key on every machine, so
each debug-signed APK carries a different signature. Android refuses to install
an APK whose signature differs from the installed one, so every update used to
mean: uninstall the app, re-install, re-download the whole ~140 MB corpus.

With one fixed key:

* tapping a newer `ShiaVerse-<version>.apk` on the phone simply updates the app;
* the downloaded databases, bookmarks, notes, and reading positions survive;
* no uninstall, no re-download.

## Status of the secret

The keystore and its passphrase are checked in **on purpose** — they are the
same for everyone who builds this repository, and the app has no accounts, no
payment, and no server, so the key only has to be *stable*, not private.

**This key must never sign a public/store release.** Anyone can read it, so
anyone could craft an "update" over such a release. Store builds are handled by
a separate workflow (`.github/workflows/production-release.yml`) which refuses
to run without the owner's private key and refuses this key if it is configured
by mistake (it checks the certificate fingerprint below).

## Production (store) signing

For a store-uploadable release, the owner generates a **new private keystore**
and stores it in GitHub Actions secrets — never in Git, artifacts, or chat:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 your-key.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | key alias |
| `ANDROID_KEY_PASSWORD` | key password |

The full runbook — key generation, backup of the key itself, the data-migration
plan for phones that hold the CI-signed 1.13.x, and the release steps — is in
[`docs/signing-and-migration-plan.md`](../../../docs/signing-and-migration-plan.md).

Note that switching keys changes the signature: a production APK **cannot**
update a CI-signed installation in place. The 1.13.2 build ships an in-app
backup (Settings → بیک اپ و منتقلی) precisely so no data is lost at that
moment. Nothing gets uninstalled without the owner's say-so.

The current CI key's certificate fingerprint (SHA-256):
`15:6A:C3:03:0B:A5:B9:A8:97:72:BB:FC:06:D5:9E:9D:38:FB:59:92:30:09:3B:46:11:30:DA:3D:99:AF:2D:11`

Valid until 2054-03-01.
