# CI signing key

`shia-library-ci.p12` is the key every CI build signs the APK with, so that
successive builds installed from download links **update over each other**.

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

The keystore and its passphrase are checked in on purpose — they are the same
for everyone who builds this repository, and the app has no accounts, no
payment, and no server, so the key only has to be *stable*, not private.

If you want a private key instead, set these four repository secrets
(Settings → Secrets and variables → Actions) and the workflow will use them in
preference to this file:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 your-key.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | key alias |
| `ANDROID_KEY_PASSWORD` | key password |

Note that switching keys changes the signature, so one last uninstall +
re-install is needed at the moment of the switch; after that, updates are
seamless again.

The current CI key's certificate fingerprint (SHA-256):
`15:6A:C3:03:0B:A5:B9:A8:97:72:BB:FC:06:D5:9E:9D:38:FB:59:92:30:09:3B:46:11:30:DA:3D:99:AF:2D:11`

Valid until 2054-03-01.
